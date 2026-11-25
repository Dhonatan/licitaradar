require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "normalizes the e-mail address" do
    user = create_user(email_address: "  Ana.Souza@Example.COM ")

    assert_equal "ana.souza@example.com", user.email_address
    assert_equal user, User.find_by(email_address: "ANA.SOUZA@example.com ")
  end

  test "requires a valid, unique e-mail address" do
    create_user(email_address: "ana@example.com")

    assert_includes User.new(email_address: "", password: "senha-secreta").tap(&:validate).errors[:email_address], "não pode ficar em branco"
    assert_includes User.new(email_address: "ana", password: "senha-secreta").tap(&:validate).errors[:email_address], "não é válido"
    assert_includes User.new(email_address: "ANA@example.com", password: "senha-secreta").tap(&:validate).errors[:email_address], "já está em uso"
  end

  test "requires a password with at least 8 characters" do
    assert_includes User.new(email_address: "ana@example.com").tap(&:validate).errors[:password], "não pode ficar em branco"
    assert_includes User.new(email_address: "ana@example.com", password: "curta").tap(&:validate).errors[:password],
                    "é muito curta (mínimo: 8 caracteres)"
    assert User.new(email_address: "ana@example.com", password: "12345678").valid?
  end

  test "checks the password confirmation when given" do
    user = User.new(email_address: "ana@example.com", password: "senha-secreta", password_confirmation: "outra-senha")

    assert_not user.valid?
    assert user.errors.key?(:password_confirmation)
  end

  test "authenticates by e-mail and password" do
    user = create_user(email_address: "ana@example.com", password: "senha-secreta")

    assert_equal user, User.authenticate_by(email_address: "Ana@Example.com", password: "senha-secreta")
    assert_nil User.authenticate_by(email_address: "ana@example.com", password: "errada")
    assert_nil User.authenticate_by(email_address: "ninguem@example.com", password: "senha-secreta")
  end

  test "updates without touching the password" do
    user = create_user

    assert User.find(user.id).update(email_address: "nova@example.com")
  end

  test "password reset tokens stop working once the password changes" do
    user = create_user
    token = user.password_reset_token

    assert_equal user, User.find_by_password_reset_token(token)

    user.update!(password: "uma-senha-nova")

    assert_nil User.find_by_password_reset_token(token)
  end

  test "new accounts are unconfirmed" do
    user = create_user(confirmed: false)

    assert_not user.confirmed?
    assert user.confirmation_pending?
    assert_equal user.email_address, user.email_address_to_confirm
    assert_not_includes User.confirmed, user
  end

  test "confirm_email confirms the account and is idempotent" do
    user = create_user(confirmed: false)

    freeze_time do
      assert user.confirm_email
      assert_equal Time.current, user.reload.confirmed_at
    end
    assert_not user.confirmation_pending?
    assert_includes User.confirmed, user

    assert_no_changes -> { user.reload.confirmed_at } do
      assert user.confirm_email
    end
  end

  test "the confirmation token finds the user and expires in 3 days" do
    user = create_user(confirmed: false)
    token = user.generate_token_for(:email_confirmation)

    assert_equal user, User.find_by_token_for(:email_confirmation, token)

    travel 3.days + 1.minute do
      assert_nil User.find_by_token_for(:email_confirmation, token)
    end
    assert_nil User.find_by_token_for(:email_confirmation, "token-invalido")
  end

  test "changing the e-mail keeps the current address until the new one is confirmed" do
    user = create_user(email_address: "ana@example.com")

    user.change_email_to(" Ana.Nova@Example.com ")
    assert user.save

    assert_equal "ana@example.com", user.reload.email_address
    assert_equal "ana.nova@example.com", user.unconfirmed_email
    assert user.confirmed?
    assert user.confirmation_pending?
    assert_equal "ana.nova@example.com", user.email_address_to_confirm

    assert user.confirm_email
    user.reload
    assert_equal "ana.nova@example.com", user.email_address
    assert_nil user.unconfirmed_email
    assert_not user.confirmation_pending?
  end

  test "asking for the current address again cancels a pending change" do
    user = create_user(email_address: "ana@example.com")
    user.update!(unconfirmed_email: "ana.nova@example.com")

    user.change_email_to("ANA@example.com")

    assert_nil user.unconfirmed_email
  end

  test "the new address must be valid and not belong to another account" do
    create_user(email_address: "bia@example.com")
    user = create_user(email_address: "ana@example.com")

    user.change_email_to("bia@example.com")
    assert_not user.valid?
    assert_includes user.errors[:unconfirmed_email], "já está em uso"

    user.change_email_to("ana-sem-arroba")
    assert_not user.valid?
    assert_includes user.errors[:unconfirmed_email], "não é válido"
  end

  test "a confirmation token stops working when the pending address changes or is confirmed" do
    user = create_user(email_address: "ana@example.com")
    user.update!(unconfirmed_email: "ana.nova@example.com")
    first_token = user.generate_token_for(:email_confirmation)

    user.update!(unconfirmed_email: "ana.outra@example.com")
    assert_nil User.find_by_token_for(:email_confirmation, first_token)

    second_token = user.generate_token_for(:email_confirmation)
    user.confirm_email
    assert_nil User.find_by_token_for(:email_confirmation, second_token)
  end

  test "confirm_email fails when the new address was taken in the meantime" do
    user = create_user(email_address: "ana@example.com")
    user.update!(unconfirmed_email: "ana.nova@example.com")
    create_user(email_address: "ana.nova@example.com")

    assert_not user.confirm_email
    assert_equal "ana@example.com", user.reload.email_address
  end

  test "destroying a user removes its sessions" do
    user = create_user
    user.sessions.create!

    assert_difference -> { Session.count }, -1 do
      user.destroy
    end
  end
end
