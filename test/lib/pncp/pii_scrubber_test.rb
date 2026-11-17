require_relative "../../lib_helper"

class Pncp::PiiScrubberTest < Minitest::Test
  MASK = Pncp::PiiScrubber::MASK

  def test_masks_formatted_valid_cpf
    assert_equal "Responsável: #{MASK}.", Pncp::PiiScrubber.call("Responsável: 529.982.247-25.")
  end

  def test_masks_unformatted_valid_cpf
    assert_equal "cpf #{MASK} ok", Pncp::PiiScrubber.call("cpf 52998224725 ok")
  end

  def test_keeps_numbers_with_invalid_check_digits
    text = "Processo 529.982.247-26"
    assert_equal text, Pncp::PiiScrubber.call(text)
  end

  def test_keeps_cnpj_untouched
    text = "CNPJ 11.222.333/0001-81 e 11222333000181"
    assert_equal text, Pncp::PiiScrubber.call(text)
  end

  def test_keeps_repeated_digit_sequences
    text = "Código 111.111.111-11"
    assert_equal text, Pncp::PiiScrubber.call(text)
  end

  def test_keeps_money_values
    text = "Valor estimado R$ 529.982.247,25"
    assert_equal text, Pncp::PiiScrubber.call(text)
  end

  def test_handles_nil_and_empty
    assert_nil Pncp::PiiScrubber.call(nil)
    assert_equal "", Pncp::PiiScrubber.call("")
  end

  def test_valid_cpf_predicate
    assert Pncp::PiiScrubber.valid_cpf?("529.982.247-25")
    refute Pncp::PiiScrubber.valid_cpf?("529.982.247-26")
    refute Pncp::PiiScrubber.valid_cpf?("123")
  end
end
