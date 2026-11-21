class DigestMailer < ApplicationMailer
  helper :tenders, :saved_searches

  # sections: SavedSearches::Digest::Section list (saved search, new tenders, total count).
  # Built by SavedSearches::Digest, which also records what was sent.
  def daily(user, sections)
    @user = user
    @sections = sections
    @tenders_count = sections.sum(&:total_count)

    mail to: user.email_address, subject: subject_for(sections, @tenders_count)
  end

  private
    def subject_for(sections, count)
      news = count == 1 ? "1 nova licitação aberta" : "#{count} novas licitações abertas"

      if sections.one?
        "#{news} para “#{sections.first.saved_search.name}”"
      else
        "#{news} para as suas buscas"
      end
    end
end
