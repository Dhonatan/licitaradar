require "test_helper"

class I18nTest < ActiveSupport::TestCase
  test "Portuguese is the default locale" do
    assert_equal :"pt-BR", I18n.default_locale
    assert_equal "não pode ficar em branco", I18n.t("errors.messages.blank")
  end

  test "keys without a Portuguese translation fall back to English" do
    assert_equal ".", I18n.t("number.format.separator")
    assert_no_match(/translation missing/i, I18n.t("datetime.distance_in_words.x_minutes", count: 2))
  end

  test "pluralized messages pick the right form" do
    assert_equal "é muito curto (mínimo: 1 caractere)", I18n.t("errors.messages.too_short", count: 1)
    assert_equal "é muito curto (mínimo: 8 caracteres)", I18n.t("errors.messages.too_short", count: 8)
  end
end
