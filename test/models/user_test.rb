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

  test "destroying a user removes its sessions" do
    user = create_user
    user.sessions.create!

    assert_difference -> { Session.count }, -1 do
      user.destroy
    end
  end
end
