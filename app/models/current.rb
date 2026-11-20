# Per-request state: the session resumed from the cookie and its user.
class Current < ActiveSupport::CurrentAttributes
  attribute :session
  delegate :user, to: :session, allow_nil: true
end
