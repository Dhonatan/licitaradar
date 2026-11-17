require_relative "../../lib_helper"

class Pncp::TenderNormalizerTest < Minitest::Test
  include PncpTestSupport

  def test_maps_identification_and_classification
    tender = Pncp::TenderNormalizer.call(pncp_record)

    assert_equal "00000000000191-1-000123/2026", tender[:pncp_control_number]
    assert_equal 2026, tender[:year]
    assert_equal 123, tender[:sequence]
    assert_equal "45/2026", tender[:purchase_number]
    assert_equal 6, tender[:modality_id]
    assert_equal "Pregão - Eletrônico", tender[:modality_name]
    assert_equal "Aberto", tender[:dispute_mode_name]
    assert_equal 1, tender[:status_id]
    assert_equal false, tender[:price_registration]
  end

  def test_maps_agency_and_location
    tender = Pncp::TenderNormalizer.call(pncp_record)

    assert_equal "00000000000191", tender[:agency_cnpj]
    assert_equal "PREFEITURA MUNICIPAL DE EXEMPLÓPOLIS", tender[:agency_name]
    assert_equal "M", tender[:agency_sphere]
    assert_equal "Secretaria de Comunicação", tender[:unit_name]
    assert_equal "9999901", tender[:ibge_code]
    assert_equal "Exemplópolis", tender[:city]
    assert_equal "PE", tender[:state], "state should be upcased"
  end

  def test_accepts_lowercase_razaosocial_and_formatted_cnpj
    tender = Pncp::TenderNormalizer.call(pncp_record(index: 1))

    assert_equal "FUNDAÇÃO DE CULTURA DE EXEMPLO", tender[:agency_name]
    assert_equal "00000000000272", tender[:agency_cnpj]
  end

  def test_parses_values_as_decimals
    tender = Pncp::TenderNormalizer.call(pncp_record)

    assert_equal BigDecimal("185000.5"), tender[:estimated_value]
    assert_nil tender[:awarded_value]
  end

  def test_parses_brasilia_times_with_offset
    tender = Pncp::TenderNormalizer.call(pncp_record)

    close_at = tender[:proposals_close_at]
    assert_equal(-3 * 3600, close_at.utc_offset)
    assert_equal Time.utc(2026, 12, 2, 12, 30), close_at.getutc
  end

  def test_parses_plain_dates_as_midnight_in_brasilia
    tender = Pncp::TenderNormalizer.call(pncp_record(index: 1))

    assert_equal Time.utc(2026, 11, 16, 3, 0), tender[:published_at].getutc
  end

  def test_builds_public_pncp_url
    tender = Pncp::TenderNormalizer.call(pncp_record)

    assert_equal "https://pncp.gov.br/app/editais/00000000000191/2026/123", tender[:pncp_url]
    assert_equal "https://compras.exemplo.gov.br/pregao/45-2026", tender[:origin_url]
  end

  def test_masks_cpf_in_free_text
    tender = Pncp::TenderNormalizer.call(pncp_record)

    refute_includes tender[:additional_info], "529.982.247-25"
    assert_includes tender[:additional_info], "***.***.***-**"
  end

  def test_blank_strings_become_nil
    tender = Pncp::TenderNormalizer.call(pncp_record(index: 1))

    assert_nil tender[:additional_info]
    assert_nil tender[:origin_url]
  end

  def test_tolerates_missing_nested_objects
    tender = Pncp::TenderNormalizer.call("numeroControlePNCP" => "X-1")

    assert_equal "X-1", tender[:pncp_control_number]
    assert_nil tender[:agency_name]
    assert_nil tender[:state]
    assert_nil tender[:pncp_url]
  end

  def test_ignores_unparseable_values
    tender = Pncp::TenderNormalizer.call(
      "numeroControlePNCP" => "X-2", "valorTotalEstimado" => "n/a", "dataEncerramentoProposta" => "amanhã", "anoCompra" => "dois mil"
    )

    assert_nil tender[:estimated_value]
    assert_nil tender[:proposals_close_at]
    assert_nil tender[:year]
  end

  def test_requires_a_control_number
    assert_raises(Pncp::InvalidRecord) { Pncp::TenderNormalizer.call("objetoCompra" => "sem identificador") }
    assert_raises(Pncp::InvalidRecord) { Pncp::TenderNormalizer.call(nil) }
  end
end
