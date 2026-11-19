# A niche preset from config/niches.yml: a named list of keywords for one line of
# business. Tenders::Search expands it into a full-text query that matches ANY include
# keyword and NONE of the exclude keywords.
#
#   Niche.all                    # => every preset, in file order
#   Niche.find("eventos")        # => #<Niche slug="eventos" ...> (nil when unknown)
#   Niche.find("eventos").tsquery
#   # => "(eventos | cerimonial | coffee <-> break | ...) & !(eventos <-> adversos)"
class Niche
  class InvalidConfig < StandardError; end

  CONFIG_PATH = Rails.root.join("config/niches.yml")

  attr_reader :slug, :name, :description, :include_keywords, :exclude_keywords

  class << self
    def all
      @all ||= load(CONFIG_PATH)
    end

    def find(slug)
      all.find { |niche| niche.slug == slug.to_s }
    end

    def load(path)
      entries = YAML.safe_load_file(path)
      raise InvalidConfig, "#{path} must be a list of niches" unless entries.is_a?(Array)

      niches = entries.map { |entry| from_config(entry) }
      duplicates = niches.map(&:slug).tally.select { |_slug, count| count > 1 }.keys
      raise InvalidConfig, "duplicate niche slugs: #{duplicates.join(", ")}" if duplicates.any?

      niches.freeze
    end

    private
      def from_config(entry)
        raise InvalidConfig, "invalid niche entry: #{entry.inspect}" unless entry.is_a?(Hash)

        new(slug: entry["slug"], name: entry["name"], description: entry["description"],
            include_keywords: entry["include"], exclude_keywords: entry["exclude"])
      end
  end

  def initialize(slug:, name:, include_keywords:, exclude_keywords: nil, description: nil)
    @slug = slug.to_s
    @name = name.to_s
    @description = description
    @include_keywords = Array(include_keywords).map(&:to_s).compact_blank.freeze
    @exclude_keywords = Array(exclude_keywords).map(&:to_s).compact_blank.freeze

    raise InvalidConfig, "niche slug #{@slug.inspect} must be lowercase letters, digits and dashes" unless @slug.match?(/\A[a-z0-9]+(-[a-z0-9]+)*\z/)
    raise InvalidConfig, "niche #{@slug} needs a name" if @name.blank?
    raise InvalidConfig, "niche #{@slug} needs at least one include keyword" if @include_keywords.empty?
  end

  # PostgreSQL to_tsquery() syntax (run it with the 'portuguese' configuration): keywords
  # are OR-ed, words inside a phrase must be adjacent (<->), exclusions are negated.
  # Accents and punctuation are stripped here, so the text is always valid tsquery syntax.
  def tsquery
    query = "(#{alternatives(include_keywords)})"
    query += " & !(#{alternatives(exclude_keywords)})" if exclude_keywords.any?
    query
  end

  def to_param
    slug
  end

  private
    def alternatives(keywords)
      keywords.map { |keyword| phrase(keyword) }.compact_blank.join(" | ")
    end

    def phrase(keyword)
      Tender.fold_accents(keyword).downcase.scan(/[[:alnum:]]+/).join(" <-> ")
    end
end
