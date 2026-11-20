# A signed-in browser. The id lives in a signed, http-only cookie; destroying the row
# signs that browser out.
class Session < ApplicationRecord
  belongs_to :user
end
