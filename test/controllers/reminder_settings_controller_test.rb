require "test_helper"

class ReminderSettingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = create_user
  end

  test "requires login" do
    patch reminder_settings_path, params: { user: { deadline_reminder_days: "7" } }

    assert_redirected_to new_session_path
    assert_equal 3, @user.reload.deadline_reminder_days
  end

  test "the account page shows the current setting" do
    @user.update!(deadline_reminder_days: 7)
    sign_in_as @user

    get account_path

    assert_select "#deadline-reminders form[action=?]", reminder_settings_path do
      assert_select "select[name='user[deadline_reminder_days]'] option", 4
      assert_select "option[selected][value='7']", "7 dias antes do prazo"
    end
  end

  test "changes the number of days" do
    sign_in_as @user

    patch reminder_settings_path, params: { user: { deadline_reminder_days: "1" } }

    assert_redirected_to account_path(anchor: "deadline-reminders")
    assert_match(/1 dia antes/, flash[:notice])
    assert_equal 1, @user.reload.deadline_reminder_days
  end

  test "turns reminders off" do
    sign_in_as @user

    patch reminder_settings_path, params: { user: { deadline_reminder_days: "0" } }

    assert_equal "Lembretes de prazo desligados.", flash[:notice]
    assert_not @user.reload.deadline_reminders?
  end

  test "rejects values that are not an option" do
    sign_in_as @user

    [ "5", "abc", "-1" ].each do |value|
      patch reminder_settings_path, params: { user: { deadline_reminder_days: value } }

      assert_redirected_to account_path(anchor: "deadline-reminders")
      assert_equal "Escolha uma das opções de lembrete.", flash[:alert]
    end
    assert_equal 3, @user.reload.deadline_reminder_days
  end
end
