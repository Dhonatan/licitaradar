require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "home explains the product and lists tracked modalities" do
    get root_path

    assert_response :success
    assert_select "h1", /Licitações abertas para o seu nicho/
    assert_select ".modalities li", Pncp::Modalities::COMPETITIVE.size
  end

  test "health check responds" do
    get rails_health_check_path

    assert_response :success
  end
end
