require "test_helper"

class SavedSearchesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = create_user(email_address: "ana@example.com", password: "senha-secreta")
  end

  test "every action requires a login" do
    saved = @user.saved_searches.create!(query: "buffet")

    get saved_searches_path
    assert_redirected_to new_session_path
    get new_saved_search_path(q: "buffet")
    assert_redirected_to new_session_path
    post saved_searches_path, params: { saved_search: { query: "buffet" } }
    assert_redirected_to new_session_path
    patch saved_search_path(saved), params: { saved_search: { query: "outra" } }
    assert_redirected_to new_session_path
    delete saved_search_path(saved)
    assert_redirected_to new_session_path

    assert_equal "buffet", saved.reload.query
  end

  test "saving from the results page goes through the login and back" do
    get new_saved_search_path(q: "buffet", states: [ "PE" ])
    assert_redirected_to new_session_path

    post session_path, params: { email_address: "ana@example.com", password: "senha-secreta" }
    assert_redirected_to "http://www.example.com/saved_searches/new?q=buffet&states%5B%5D=PE"

    follow_redirect!
    assert_response :success
    assert_select "input[name=?][value=?]", "saved_search[query]", "buffet"
  end

  test "index lists the user's searches with criteria, status and open matches" do
    create_open_tender(object_description: "Serviço de buffet", state: "PE")
    create_open_tender(object_description: "Serviço de buffet", state: "BA")
    mine = @user.saved_searches.create!(name: "Buffet em PE", query: "buffet", states: %w[ PE ], min_value: "1000", max_value: "50000")
    paused = @user.saved_searches.create!(name: "Pausada", niche_slug: "eventos", active: false)
    others = create_user.saved_searches.create!(name: "Busca de outra pessoa", query: "pneus")
    sign_in_as @user

    get saved_searches_path

    assert_response :success
    assert_select ".saved-search-card", 2
    assert_select "##{ActionView::RecordIdentifier.dom_id(mine)}" do
      assert_select "h2", "Buffet em PE"
      assert_select ".badge", "alerta diário"
      assert_select ".criteria li", text: "Palavras-chave: buffet"
      assert_select ".criteria li", text: "Estados: PE"
      assert_select ".criteria li", text: "Valor estimado: de R$ 1.000,00 a R$ 50.000,00"
      assert_select "a[href=?]", tenders_path(mine.search_params), text: "Ver 1 licitação aberta"
      assert_select "a[href=?]", edit_saved_search_path(mine)
      assert_select "form[action=?] button", saved_search_path(mine), text: "Excluir"
    end
    assert_select "##{ActionView::RecordIdentifier.dom_id(paused)} .badge", "pausada"
    assert_select "##{ActionView::RecordIdentifier.dom_id(paused)} .criteria li", text: "Nicho: Eventos"
    assert_select "##{ActionView::RecordIdentifier.dom_id(others)}", 0
  end

  test "index explains how to save a search when there is none" do
    sign_in_as @user

    get saved_searches_path

    assert_select ".empty-state", /Você ainda não salvou nenhuma busca/
  end

  test "new is pre-filled from the search params" do
    sign_in_as @user

    get new_saved_search_path(q: "buffet", niche: "eventos", states: [ "PE", "PB" ], modality_ids: [ "8" ], min_value: "1.000",
                              closing_within: "15", sort: "value", page: "2")

    assert_response :success
    assert_select "form[action=?][method=post]", saved_searches_path do
      assert_select "input[name=?][value=?]", "saved_search[name]", "“buffet” · Eventos · PE, PB"
      assert_select "input[name=?][value=?]", "saved_search[query]", "buffet"
      assert_select "select[name=?] option[selected][value=?]", "saved_search[niche_slug]", "eventos"
      assert_select "select[name=?] option[selected]", "saved_search[states][]", 2
      assert_select "input[type=checkbox][name=?][value=?][checked]", "saved_search[modality_ids][]", "8"
      assert_select "input[name=?][value=?]", "saved_search[min_value]", "1000"
      assert_select "select[name=?] option[selected][value=?]", "saved_search[closing_within]", "15"
      assert_select "input[type=checkbox][name=?][checked]", "saved_search[notify_daily]"
      assert_select "input[type=checkbox][name=?][checked]", "saved_search[active]"
    end
  end

  test "create saves the search for the current user" do
    sign_in_as @user

    assert_difference -> { @user.saved_searches.count }, 1 do
      post saved_searches_path, params: { saved_search: { name: "Eventos no Nordeste", query: "buffet", niche_slug: "eventos",
                                                          states: [ "", "PE", "BA" ], modality_ids: [ "", "8" ], min_value: "",
                                                          max_value: "100.000", closing_within: "", notify_daily: "1", active: "1" } }
    end

    saved = @user.saved_searches.last
    assert_redirected_to saved_searches_path
    assert_equal "Busca “Eventos no Nordeste” salva.", flash[:notice]
    assert_equal "buffet", saved.query
    assert_equal "eventos", saved.niche_slug
    assert_equal({ "states" => %w[ PE BA ], "modality_ids" => [ 8 ], "max_value" => "100000" }, saved.filters)
    assert saved.notify_daily?
  end

  test "create ignores attempts to save for someone else" do
    other = create_user
    sign_in_as @user

    post saved_searches_path, params: { saved_search: { query: "buffet", user_id: other.id } }

    assert_equal 0, other.saved_searches.count
    assert_equal 1, @user.saved_searches.count
  end

  test "create re-renders the form with errors" do
    sign_in_as @user

    assert_no_difference -> { SavedSearch.count } do
      post saved_searches_path, params: { saved_search: { name: "Vazia", query: "", states: [ "" ] } }
    end

    assert_response :unprocessable_content
    assert_select ".form-errors", /pelo menos uma palavra-chave/
    assert_select "input[name=?][value=?]", "saved_search[name]", "Vazia"
  end

  test "edit and update change the user's search" do
    saved = @user.saved_searches.create!(name: "Buffet", query: "buffet", states: %w[ PE ])
    sign_in_as @user

    get edit_saved_search_path(saved)
    assert_response :success
    assert_select "form[action=?]", saved_search_path(saved)

    patch saved_search_path(saved), params: { saved_search: { name: "Buffet pausado", states: [ "" ], notify_daily: "0", active: "0" } }

    assert_redirected_to saved_searches_path
    saved.reload
    assert_equal "Buffet pausado", saved.name
    assert_equal "buffet", saved.query
    assert_equal({}, saved.filters)
    assert_not saved.notify_daily?
    assert_not saved.active?
  end

  test "update re-renders the form with errors" do
    saved = @user.saved_searches.create!(query: "buffet")
    sign_in_as @user

    patch saved_search_path(saved), params: { saved_search: { niche_slug: "astronautica" } }

    assert_response :unprocessable_content
    assert_select ".form-errors", /Nicho não está incluído na lista/
    assert_nil saved.reload.niche_slug
  end

  test "destroy removes the user's search" do
    saved = @user.saved_searches.create!(name: "Buffet", query: "buffet")
    sign_in_as @user

    assert_difference -> { SavedSearch.count }, -1 do
      delete saved_search_path(saved)
    end

    assert_redirected_to saved_searches_path
    assert_equal "Busca “Buffet” excluída.", flash[:notice]
  end

  test "other users' searches are not found" do
    others = create_user.saved_searches.create!(query: "pneus")
    sign_in_as @user

    get edit_saved_search_path(others)
    assert_response :not_found

    patch saved_search_path(others), params: { saved_search: { query: "buffet" } }
    assert_response :not_found

    assert_no_difference -> { SavedSearch.count } do
      delete saved_search_path(others)
    end
    assert_response :not_found
    assert_equal "pneus", others.reload.query
  end

  test "the results page links to saving the current search" do
    get tenders_path(q: "buffet", states: [ "PE" ], sort: "value")

    assert_select "a.save-search[href=?][data-turbo-frame='_top']", new_saved_search_path(q: "buffet", states: [ "PE" ])
  end

  test "the results page without criteria has no save button" do
    get tenders_path

    assert_select "a.save-search", 0
  end

  test "signed-in users see their searches in the header" do
    sign_in_as @user

    get root_path

    assert_select "nav a[href=?]", saved_searches_path, text: "Minhas buscas"
  end
end
