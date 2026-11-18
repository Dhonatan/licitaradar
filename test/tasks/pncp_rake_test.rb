require "test_helper"
require "rake"

class PncpRakeTest < ActiveSupport::TestCase
  PROPOSTA_URL = "https://pncp.gov.br/api/consulta/v1/contratacoes/proposta".freeze

  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?("pncp:sync")
    Rake::Task["pncp:sync"].reenable
    stub_request(:get, PROPOSTA_URL).with(query: hash_including({})).to_return(status: 204, body: "")
  end

  test "pncp:sync syncs the modalities in MODALITIES and prints a summary" do
    output, = with_modalities("6, 8") { capture_io { Rake::Task["pncp:sync"].invoke } }

    assert_equal [ 6, 8 ], SyncRun.order(:id).pluck(:modality_id)
    assert_match(/Pregão - Eletrônico\s+succeeded\s+pages=1 fetched=0/, output)
    assert_match(/Dispensa de Licitação/, output)
  end

  test "pncp:sync aborts when a modality fails" do
    stub_request(:get, PROPOSTA_URL).with(query: hash_including("codigoModalidadeContratacao" => "6"))
      .to_return(status: 404, body: "")

    error = assert_raises(SystemExit) do
      with_modalities("6") { capture_io { Rake::Task["pncp:sync"].invoke } }
    end

    assert_not error.success?
    assert SyncRun.sole.failed?
  end

  private
    def with_modalities(value)
      previous = ENV["MODALITIES"]
      ENV["MODALITIES"] = value
      yield
    ensure
      ENV["MODALITIES"] = previous
    end
end
