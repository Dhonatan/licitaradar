require_relative "../../lib_helper"

class Pncp::ModalitiesTest < Minitest::Test
  def test_names_known_codes
    assert_equal "Pregão - Eletrônico", Pncp::Modalities.name_for(6)
    assert_equal "Dispensa de Licitação", Pncp::Modalities.name_for("8")
  end

  def test_falls_back_for_unknown_codes
    assert_equal "Modalidade 99", Pncp::Modalities.name_for(99)
    refute Pncp::Modalities.valid?(99)
  end

  def test_competitive_modalities_are_all_known
    assert Pncp::Modalities::COMPETITIVE.all? { |id| Pncp::Modalities.valid?(id) }
  end
end
