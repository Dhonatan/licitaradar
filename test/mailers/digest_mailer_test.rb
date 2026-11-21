require "test_helper"
require Rails.root.join("test/mailers/previews/digest_mailer_preview").to_s

class DigestMailerTest < ActionMailer::TestCase
  setup do
    @user = create_user(email_address: "ana@example.com")
    @saved_search = @user.saved_searches.create!(name: "Buffet em PE", query: "buffet", states: %w[ PE ])
  end

  def section(tenders, total_count: tenders.size, saved_search: @saved_search)
    SavedSearches::Digest::Section.new(saved_search: saved_search, tenders: tenders, total_count: total_count)
  end

  test "daily lists the new tenders of each saved search with deadline, value and links" do
    tender = create_open_tender(object_description: "Serviço de buffet para formatura", agency_name: "Prefeitura de Exemplópolis",
                                estimated_value: 12_345.6, proposals_close_at: 3.days.from_now.change(hour: 14, min: 0))
    secret = create_open_tender(object_description: "Serviço de buffet sigiloso", estimated_value: 0)
    other_search = @user.saved_searches.create!(name: "Eventos", niche_slug: "eventos")
    other = create_open_tender(object_description: "Locação de palco para eventos")

    mail = DigestMailer.daily(@user, [ section([ tender, secret ]), section([ other ], saved_search: other_search) ])

    assert_equal [ "ana@example.com" ], mail.to
    assert_equal "3 novas licitações abertas para as suas buscas", mail.subject

    [ mail.html_part.body.to_s, mail.text_part.body.to_s ].each do |body|
      assert_includes body, "Buffet em PE"
      assert_includes body, "Palavras-chave: buffet"
      assert_includes body, "Serviço de buffet para formatura"
      assert_includes body, "Prefeitura de Exemplópolis"
      assert_includes body, "Encerra em 3 dias"
      assert_includes body, "R$ 12.345,60"
      assert_includes body, "Valor sigiloso"
      assert_includes body, "http://example.com/tenders/#{tender.id}"
      assert_includes body, "Eventos"
      assert_includes body, "Locação de palco para eventos"
      assert_includes body, "http://example.com/saved_searches"
      assert_not_includes body, "E mais"
    end
    assert_includes mail.text_part.body.to_s, "http://example.com/tenders?q=buffet&states%5B%5D=PE"
  end

  test "daily has unsubscribe links for each search and for every alert" do
    mail = DigestMailer.daily(@user, [ section([ create_open_tender(object_description: "Serviço de buffet") ]) ])

    all_url = mail["List-Unsubscribe"].to_s.delete_prefix("<").delete_suffix(">")
    assert_match %r{\Ahttp://example\.com/unsubscribe/[^/]+\z}, all_url
    assert_equal "List-Unsubscribe=One-Click", mail["List-Unsubscribe-Post"].to_s
    assert_equal @user, User.find_by_token_for(:digest_unsubscribe_all, all_url.split("/").last)

    search_token = mail.text_part.body.to_s[%r{Parar o alerta desta busca: http://example\.com/unsubscribe/(\S+)}, 1]
    assert_equal @saved_search, SavedSearch.find_by_token_for(:digest_unsubscribe, search_token)
    assert_includes mail.text_part.body.to_s, "Parar todos os alertas: #{all_url}"
    assert_includes mail.html_part.body.to_s, all_url
    assert_includes mail.html_part.body.to_s, "Parar o alerta desta busca"
  end

  test "daily with a single search names it in the subject" do
    mail = DigestMailer.daily(@user, [ section([ create_open_tender(object_description: "Serviço de buffet") ]) ])

    assert_equal "1 nova licitação aberta para “Buffet em PE”", mail.subject
  end

  test "daily says how many more tenders did not fit in the e-mail" do
    mail = DigestMailer.daily(@user, [ section([ create_open_tender(object_description: "Serviço de buffet") ], total_count: 25) ])

    assert_equal "25 novas licitações abertas para “Buffet em PE”", mail.subject
    assert_includes mail.html_part.body.to_s, "E mais 24 licitações."
    assert_includes mail.text_part.body.to_s, "E mais 24 licitações."
  end

  test "the preview renders from the database or from an in-memory example" do
    mail = DigestMailerPreview.new.daily

    assert_equal [ "ana@example.com" ], mail.to
    assert_includes mail.text_part.body.to_s, "organização de eventos"

    create_open_tender(object_description: "Serviço de buffet")

    assert_includes DigestMailerPreview.new.daily.text_part.body.to_s, "Serviço de buffet"
  end
end
