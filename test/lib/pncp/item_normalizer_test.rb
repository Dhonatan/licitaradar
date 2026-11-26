require_relative "../../lib_helper"

class Pncp::ItemNormalizerTest < Minitest::Test
  include PncpTestSupport

  def items
    JSON.parse(pncp_fixture("itens_page_1.json")) + JSON.parse(pncp_fixture("itens_page_2.json"))
  end

  def test_maps_the_item_fields
    attributes = Pncp::ItemNormalizer.call(items.first)

    assert_equal 1, attributes[:number]
    assert_equal "Resma de papel sulfite A4, 75 g/m², pacote com 500 folhas", attributes[:description]
    assert_equal "M", attributes[:material_or_service]
    assert_equal BigDecimal("500"), attributes[:quantity]
    assert_equal "Pacote", attributes[:unit]
    assert_equal BigDecimal("27.9"), attributes[:unit_estimated_value]
    assert_equal BigDecimal("13950"), attributes[:total_estimated_value]
    refute attributes[:confidential_budget]
    assert_equal "Em Andamento", attributes[:status_name]
    assert_equal "Menor preço", attributes[:judgment_criterion_name]
    assert_equal "Participação exclusiva para ME/EPP", attributes[:benefit_name]
    assert_equal "Bens móveis", attributes[:category_name]
    assert_equal Time.new(2026, 11, 11, 16, 42, 5, "-03:00"), attributes[:source_updated_at]
  end

  def test_keeps_four_decimal_places
    assert_equal BigDecimal("1.2575"), Pncp::ItemNormalizer.call(items[1])[:unit_estimated_value]
  end

  def test_confidential_budget_has_no_values
    attributes = Pncp::ItemNormalizer.call(items[2])

    assert attributes[:confidential_budget]
    assert_nil attributes[:unit_estimated_value]
    assert_nil attributes[:total_estimated_value]
    assert_equal "S", attributes[:material_or_service]
  end

  def test_tolerates_strings_and_missing_values
    attributes = Pncp::ItemNormalizer.call({ "numeroItem" => "7", "quantidade" => "2.5", "valorTotal" => "abc",
                                             "orcamentoSigiloso" => "false", "descricao" => "CPF 529.982.247-25" })

    assert_equal 7, attributes[:number]
    assert_equal BigDecimal("2.5"), attributes[:quantity]
    assert_nil attributes[:total_estimated_value]
    assert_nil attributes[:unit_estimated_value]
    refute attributes[:confidential_budget]
    assert_equal "CPF ***.***.***-**", attributes[:description]
  end

  def test_rejects_records_without_a_number
    assert_raises(Pncp::InvalidRecord) { Pncp::ItemNormalizer.call({ "descricao" => "Sem número" }) }
  end
end
