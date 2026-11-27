require "test_helper"

module Watches
  class NotesControllerTest < ActionDispatch::IntegrationTest
    include ActionView::RecordIdentifier

    setup do
      @user = create_user
      @tender = create_open_tender
      @watch = Watch.watch!(@user, @tender)
      sign_in_as @user
    end

    def frame_headers
      { "Turbo-Frame" => dom_id(@watch, :note) }
    end

    test "the tender page shows the note frame of a watched tender" do
      @watch.update!(note: "Pedir certidões até sexta")

      get tender_path(@tender)

      assert_select "##{dom_id(@tender, :watch_note)} turbo-frame##{dom_id(@watch, :note)}" do
        assert_select ".watch-note__text", /Pedir certidões até sexta/
        assert_select "a[href=?]", edit_tender_watch_note_path(@tender), text: "Editar nota"
      end
    end

    test "the watchlist shows the notes" do
      @watch.update!(note: "Visita técnica obrigatória")

      get watches_path

      assert_select "##{dom_id(@watch)} turbo-frame##{dom_id(@watch, :note)}", /Visita técnica obrigatória/
    end

    test "a watch without a note offers to add one" do
      get tender_path(@tender)

      assert_select "turbo-frame##{dom_id(@watch, :note)} a[href=?]", edit_tender_watch_note_path(@tender), text: "Adicionar nota privada"
    end

    test "edit renders the form inside the frame" do
      get edit_tender_watch_note_path(@tender), headers: frame_headers

      assert_response :success
      assert_select "turbo-frame##{dom_id(@watch, :note)} form[action=?]", tender_watch_note_path(@tender) do
        assert_select "textarea[name='watch[note]'][maxlength='#{Watch::MAX_NOTE_LENGTH}']"
        assert_select "a[href=?]", tender_watch_note_path(@tender), text: "Cancelar"
      end
    end

    test "update saves the note and answers with the frame" do
      patch tender_watch_note_path(@tender), params: { watch: { note: "  Ligar para o pregoeiro\r\nLevar amostras  " } }, headers: frame_headers

      assert_response :success
      assert_equal "Ligar para o pregoeiro\nLevar amostras", @watch.reload.note
      assert_select "turbo-frame##{dom_id(@watch, :note)} .watch-note__text", /Ligar para o pregoeiro/
    end

    test "update without Turbo goes back to the tender" do
      patch tender_watch_note_path(@tender), params: { watch: { note: "Nota" } }

      assert_redirected_to tender_path(@tender)
      assert_equal "Nota", @watch.reload.note
    end

    test "a blank note is removed" do
      @watch.update!(note: "Antiga")

      patch tender_watch_note_path(@tender), params: { watch: { note: "   " } }, headers: frame_headers

      assert_nil @watch.reload.note
      assert_select "a", text: "Adicionar nota privada"
    end

    test "a note that is too long is refused with the form" do
      patch tender_watch_note_path(@tender), params: { watch: { note: "a" * (Watch::MAX_NOTE_LENGTH + 1) } }, headers: frame_headers

      assert_response :unprocessable_content
      assert_select "turbo-frame##{dom_id(@watch, :note)} .form-errors"
      assert_nil @watch.reload.note
    end

    test "notes are escaped" do
      @watch.update!(note: "<script>alert(1)</script>")

      get tender_path(@tender)

      assert_select ".watch-note__text script", 0
      assert_includes response.body, "&lt;script&gt;alert(1)&lt;/script&gt;"
    end

    test "show answers with the frame, or sends plain visits to the tender" do
      get tender_watch_note_path(@tender), headers: frame_headers
      assert_select "turbo-frame##{dom_id(@watch, :note)}"

      get tender_watch_note_path(@tender)
      assert_redirected_to tender_path(@tender)
    end

    test "only the owner of the watch can see or change its note" do
      other = create_user
      Watch.watch!(other, create_open_tender)
      sign_in_as other

      get edit_tender_watch_note_path(@tender)
      assert_response :not_found

      patch tender_watch_note_path(@tender), params: { watch: { note: "Intrusa" } }
      assert_response :not_found
      assert_nil @watch.reload.note
    end

    test "watching from the tender page adds the note frame, unwatching removes it" do
      @watch.destroy

      post tender_watch_path(@tender), as: :turbo_stream
      assert_select "turbo-stream[action=update][target=?] template turbo-frame", dom_id(@tender, :watch_note)

      delete tender_watch_path(@tender), as: :turbo_stream
      assert_select "turbo-stream[action=update][target=?] template turbo-frame", dom_id(@tender, :watch_note), count: 0
    end
  end
end
