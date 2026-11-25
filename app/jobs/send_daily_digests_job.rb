# Sends the daily e-mail digest (see SavedSearches::Digest) to every confirmed user with
# at least one active saved search with daily alerts on (SavedSearch.notifiable). Scheduled every morning in
# config/recurring.yml; running it again the same day only sends what is new.
class SendDailyDigestsJob < ApplicationJob
  queue_as :default

  # Returns { users:, sent:, failed: }.
  def perform
    stats = { users: 0, sent: 0, failed: 0 }

    User.where(id: SavedSearch.notifiable.select(:user_id)).find_each do |user|
      stats[:users] += 1
      stats[:sent] += 1 if SavedSearches::Digest.new(user).deliver
    rescue StandardError => error
      # One bad address or record must not stop everybody else's digest.
      stats[:failed] += 1
      Rails.error.report(error, handled: true, context: { user_id: user.id })
    end

    logger.info "Daily digests: #{stats[:sent]} sent, #{stats[:failed]} failed, #{stats[:users]} users checked"
    stats
  end
end
