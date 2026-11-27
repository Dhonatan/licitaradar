require "test_helper"

module Api
  module V1
    class WatchesControllerTest < ActionDispatch::IntegrationTest
      setup do
        @user = create_user
        @headers = auth_headers(api_token_for(@user))
        @tender = create_open_tender(object_description: "Serviço de buffet", proposals_close_at: 5.days.from_now)
      end

      test "every action requires a valid bearer token" do
        watch = Watch.watch!(@user, @tender)

        get api_v1_watches_path
        assert_response :unauthorized
        post api_v1_watches_path, params: { watch: { tender_id: @tender.id } }, as: :json
        assert_response :unauthorized
        delete api_v1_watch_path(watch)
        assert_response :unauthorized

        assert_equal 1, Watch.count
      end

      test "index lists the owner's watches, open tenders first by deadline" do
        closed = create_open_tender(object_description: "Aquisição de pneus", proposals_close_at: 2.days.ago)
        soon = create_open_tender(object_description: "Locação de palco", proposals_close_at: 1.day.from_now)
        [ closed, @tender, soon ].each { |tender| Watch.watch!(@user, tender) }
        Watch.watch!(@user, soon).update!(note: "Levar amostras")
        Watch.watch!(create_user, create_open_tender(object_description: "De outra pessoa"))

        get api_v1_watches_path, headers: @headers

        assert_response :success
        data = response.parsed_body["data"]
        assert_equal [ soon.id, @tender.id, closed.id ], data.pluck("tender_id")
        json = data.first
        assert_equal "open", json["proposals_status"]
        assert_equal "Levar amostras", json["note"]
        assert_nil json["reminded_close_at"]
        assert_equal "Locação de palco", json.dig("tender", "object")
        assert_equal soon.proposals_close_at.iso8601, json.dig("tender", "proposals_close_at")
        assert_equal api_v1_watch_url(json["id"]), json.dig("links", "self")
        assert_equal "closed", data.last["proposals_status"]
      end

      test "create watches a tender, with an optional note" do
        post api_v1_watches_path, params: { watch: { tender_id: @tender.id, note: "Pedir certidões" } }, headers: @headers, as: :json

        assert_response :created
        watch = @user.watches.sole
        assert_equal api_v1_watch_url(watch), response.headers["Location"]
        assert_equal "Pedir certidões", watch.note
        assert_equal @tender.id, response.parsed_body.dig("data", "tender_id")
      end

      test "create is idempotent and replaces the note only when one is sent" do
        watch = Watch.watch!(@user, @tender)
        watch.update!(note: "Antiga")

        post api_v1_watches_path, params: { watch: { tender_id: @tender.id } }, headers: @headers, as: :json
        assert_response :ok
        assert_equal "Antiga", watch.reload.note

        post api_v1_watches_path, params: { watch: { tender_id: @tender.id, note: "Nova" } }, headers: @headers, as: :json
        assert_response :ok
        assert_equal "Nova", watch.reload.note
        assert_equal 1, Watch.count
      end

      test "create answers 404 for unknown tenders and 400 without a body" do
        post api_v1_watches_path, params: { watch: { tender_id: 0 } }, headers: @headers, as: :json
        assert_response :not_found
        assert_equal "not_found", response.parsed_body.dig("error", "code")

        post api_v1_watches_path, params: {}, headers: @headers, as: :json
        assert_response :bad_request
      end

      test "create refuses notes that are too long" do
        post api_v1_watches_path, params: { watch: { tender_id: @tender.id, note: "a" * (Watch::MAX_NOTE_LENGTH + 1) } },
                                  headers: @headers, as: :json

        assert_response :unprocessable_content
        assert_equal "invalid", response.parsed_body.dig("error", "code")
        assert response.parsed_body.dig("error", "details", "note").present?
        assert_equal 0, Watch.count
      end

      test "destroy stops watching" do
        watch = Watch.watch!(@user, @tender)

        delete api_v1_watch_path(watch), headers: @headers

        assert_response :no_content
        assert_equal 0, Watch.count
      end

      test "the watches of other users are not found" do
        watch = Watch.watch!(create_user, @tender)

        delete api_v1_watch_path(watch), headers: @headers

        assert_response :not_found
        assert Watch.exists?(watch.id)
      end
    end
  end
end
