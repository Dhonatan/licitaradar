module Pncp
  # Masks CPF numbers (personal data under LGPD) that sometimes show up in the
  # free-text fields of public tenders. Only numbers with valid CPF check digits
  # are masked, so CNPJs, process numbers and prices are left untouched.
  module PiiScrubber
    CPF_PATTERN = /(?<![\d.\/-])\d{3}\.?\d{3}\.?\d{3}-?\d{2}(?![\d\/-]|\.\d)/
    MASK = "***.***.***-**".freeze

    module_function

    def call(text)
      return text if text.nil?

      text.gsub(CPF_PATTERN) { |match| valid_cpf?(match) ? MASK : match }
    end

    def valid_cpf?(value)
      digits = value.to_s.delete("^0-9")
      return false unless digits.length == 11
      return false if digits.squeeze.length == 1 # 000.000.000-00, 111..., etc.

      numbers = digits.chars.map(&:to_i)
      check_digit(numbers.first(9)) == numbers[9] && check_digit(numbers.first(10)) == numbers[10]
    end

    def check_digit(numbers)
      weight = numbers.length + 1
      sum = numbers.each_with_index.sum { |number, index| number * (weight - index) }
      remainder = (sum * 10) % 11
      remainder == 10 ? 0 : remainder
    end
  end
end
