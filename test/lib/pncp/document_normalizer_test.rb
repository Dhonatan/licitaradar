require_relative "../../lib_helper"

class Pncp::DocumentNormalizerTest < Minitest::Test
  include PncpTestSupport

  def documents
    JSON.parse(pncp_fixture("arquivos.json"))
  end

  def test_maps_the_document_fields
    attributes = Pncp::DocumentNormalizer.call(documents.first)

    assert_equal 1, attributes[:sequence]
    assert_equal "Edital do Pregão Eletrônico 45/2026", attributes[:title]
    assert_equal 2, attributes[:type_id]
    assert_equal "Edital", attributes[:type_name]
    assert_equal "https://pncp.gov.br/pncp-api/v1/orgaos/00000000000191/compras/2026/12/arquivos/1", attributes[:url]
    assert_equal Time.new(2026, 11, 10, 9, 15, 22, "-03:00"), attributes[:published_at]
    assert attributes[:active]
  end

  def test_masks_cpfs_in_titles_and_reads_times_without_seconds
    attributes = Pncp::DocumentNormalizer.call(documents[1])

    assert_equal "Termo de Referência - responsável ***.***.***-**", attributes[:title]
    assert_equal Time.new(2026, 11, 10, 9, 16, 0, "-03:00"), attributes[:published_at]
  end

  def test_flags_inactive_documents
    refute Pncp::DocumentNormalizer.call(documents[2])[:active]
    assert Pncp::DocumentNormalizer.call({ "sequencialDocumento" => 1 })[:active]
  end

  def test_falls_back_for_missing_title_and_url
    record = { "sequencialDocumento" => "4", "tipoDocumentoNome" => "Ata de Registro de Preço", "titulo" => " " }

    attributes = Pncp::DocumentNormalizer.call(record, purchase_url: "https://pncp.test/api/pncp/v1/orgaos/00000000000191/compras/2026/12")

    assert_equal 4, attributes[:sequence]
    assert_equal "Ata de Registro de Preço", attributes[:title]
    assert_equal "https://pncp.test/api/pncp/v1/orgaos/00000000000191/compras/2026/12/arquivos/4", attributes[:url]
    assert_equal "Documento 4", Pncp::DocumentNormalizer.call({ "sequencialDocumento" => 4 })[:title]
    assert_nil Pncp::DocumentNormalizer.call({ "sequencialDocumento" => 4 })[:url]
  end

  def test_rejects_records_without_a_sequence
    assert_raises(Pncp::InvalidRecord) { Pncp::DocumentNormalizer.call({ "titulo" => "Edital" }) }
    assert_raises(Pncp::InvalidRecord) { Pncp::DocumentNormalizer.call(nil) }
  end
end
