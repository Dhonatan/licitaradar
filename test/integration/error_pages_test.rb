require "test_helper"

# Production shows the static pages in public/ instead of the debug page the test
# environment shows (consider_all_requests_local); these tests switch to that behaviour.
class ErrorPagesTest < ActionDispatch::IntegrationTest
  ERROR_PAGES = %w[ 400 404 406-unsupported-browser 422 500 ].freeze

  setup do
    @show_detailed_exceptions = Rails.application.env_config["action_dispatch.show_detailed_exceptions"]
    Rails.application.env_config["action_dispatch.show_detailed_exceptions"] = false
  end

  teardown do
    Rails.application.env_config["action_dispatch.show_detailed_exceptions"] = @show_detailed_exceptions
  end

  test "an unknown tender shows the friendly 404 page" do
    get tender_path(0)

    assert_response :not_found
    assert_select "h1", "Página não encontrada"
    assert_select "a[href='/tenders']", "Buscar licitações abertas"
  end

  test "an unknown URL shows the friendly 404 page" do
    get "/pagina-que-nao-existe"

    assert_response :not_found
    assert_select "h1", "Página não encontrada"
  end

  test "an unknown saved search of the user is a 404 too" do
    sign_in_as create_user

    get edit_saved_search_path(0)

    assert_response :not_found
    assert_select "h1", "Página não encontrada"
  end

  test "outdated browsers get the unsupported browser page" do
    old_chrome = "Mozilla/5.0 (Windows NT 6.1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/49.0.2623.112 Safari/537.36"

    get root_path, headers: { "User-Agent" => old_chrome }

    assert_response :not_acceptable
    assert_select "h1", "Navegador não suportado"
  end

  test "the API keeps answering errors in JSON" do
    get api_v1_tender_path(0), headers: auth_headers(api_token_for(create_user))

    assert_response :not_found
    assert_equal "not_found", response.parsed_body.dig("error", "code")
  end

  test "every error page is a standalone Portuguese page with a way back" do
    ERROR_PAGES.each do |name|
      html = Rails.public_path.join("#{name}.html").read
      document = Nokogiri::HTML5(html)

      assert_equal "pt-BR", document.at("html")["lang"], name
      assert_match(/LicitaRadar/, document.at("title").text, name)
      assert document.at("a[href='/']"), "#{name} links to the home page"
      assert_empty document.css("link[rel=stylesheet], script[src]"), "#{name} must not depend on assets"
    end
  end
end
