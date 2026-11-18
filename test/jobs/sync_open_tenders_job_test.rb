require "test_helper"

class SyncOpenTendersJobTest < ActiveJob::TestCase
  PROPOSTA_URL = "https://pncp.gov.br/api/consulta/v1/contratacoes/proposta".freeze

  setup do
    stub_request(:get, PROPOSTA_URL).with(query: hash_including({})).to_return(status: 204, body: "")
  end

  test "syncs the given modalities" do
    stub_request(:get, PROPOSTA_URL)
      .with(query: hash_including("codigoModalidadeContratacao" => "6", "pagina" => "1"))
      .to_return(status: 200, body: file_fixture("pncp/proposta_page_2.json").read)

    runs = SyncOpenTendersJob.perform_now([ 6 ])

    assert_equal [ 6 ], runs.map(&:modality_id)
    assert_equal 1, Tender.count
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
end
