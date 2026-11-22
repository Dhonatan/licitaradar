require "test_helper"

class SyncOpenTendersJobTest < ActiveJob::TestCase
  include ActionMailer::TestHelper

  PROPOSTA_URL = "https://pncp.gov.br/api/consulta/v1/contratacoes/proposta".freeze

  setup do
    stub_request(:get, PROPOSTA_URL).with(query: hash_including({})).to_return(status: 204, body: "")
  end

  # 400 is not retried by Pncp::Client, so a failing modality fails fast (no backoff sleeps).
  def stub_failure(modality_id)
    stub_request(:get, PROPOSTA_URL)
      .with(query: hash_including("codigoModalidadeContratacao" => modality_id.to_s))
      .to_return(status: 400, body: "Bad Request")
  end

  test "syncs the given modalities" do
    stub_request(:get, PROPOSTA_URL)
      .with(query: hash_including("codigoModalidadeContratacao" => "6", "pagina" => "1"))
      .to_return(status: 200, body: file_fixture("pncp/proposta_page_2.json").read)

    runs = SyncOpenTendersJob.perform_now([ 6 ])

    assert_equal [ 6 ], runs.map(&:modality_id)
    assert_equal 1, Tender.count
    assert_equal [ 1 ], runs.map(&:attempt)
  end

  test "syncs every competitive modality by default" do
    SyncOpenTendersJob.perform_now

    assert_equal Pncp::Modalities::COMPETITIVE.sort, SyncRun.pluck(:modality_id).sort
  end

  test "can be enqueued" do
    assert_enqueued_with(job: SyncOpenTendersJob, args: [ [ 6, 8 ] ]) do
      SyncOpenTendersJob.perform_later([ 6, 8 ])
    end
  end

  test "does not retry when every modality succeeds" do
    assert_no_enqueued_jobs only: SyncOpenTendersJob do
      SyncOpenTendersJob.perform_now([ 6, 8 ])
    end
  end

  test "retries only the failed modalities later, with the next attempt number" do
    stub_failure(8)

    freeze_time do
      assert_enqueued_with(job: SyncOpenTendersJob, args: [ [ 8 ], 2 ], at: 15.minutes.from_now) do
        SyncOpenTendersJob.perform_now([ 6, 8 ])
      end
    end

    assert_equal %w[ succeeded failed ], SyncRun.order(:modality_id).pluck(:status)
  end

  test "waits longer before the last attempt and records the attempt on the runs" do
    stub_failure(8)

    freeze_time do
      assert_enqueued_with(job: SyncOpenTendersJob, args: [ [ 8 ], 3 ], at: 45.minutes.from_now) do
        SyncOpenTendersJob.perform_now([ 8 ], 2)
      end
    end

    assert_equal 2, SyncRun.sole.attempt
  end

  test "alerts the admins when the last attempt fails" do
    stub_failure(8)

    with_env("ADMIN_EMAIL" => "ops@example.com, outra@example.com") do
      assert_no_enqueued_jobs only: SyncOpenTendersJob do
        assert_emails 1 do
          assert_error_reported(SyncOpenTendersJob::SyncFailed) do
            SyncOpenTendersJob.perform_now([ 8 ], SyncOpenTendersJob::MAX_ATTEMPTS)
          end
        end
      end
    end

    mail = ActionMailer::Base.deliveries.last
    assert_equal [ "ops@example.com", "outra@example.com" ], mail.to
    assert_match "Dispensa de Licitação", mail.body.to_s
    assert_match "HTTP 400", mail.body.to_s
  end

  test "only reports the error when no admin e-mail is configured" do
    stub_failure(8)

    with_env("ADMIN_EMAIL" => nil) do
      assert_no_emails do
        assert_error_reported(SyncOpenTendersJob::SyncFailed) do
          SyncOpenTendersJob.perform_now([ 8 ], SyncOpenTendersJob::MAX_ATTEMPTS)
        end
      end
    end
  end
end
