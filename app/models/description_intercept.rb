class DescriptionIntercept < Sequel::Model
  GUIDANCE_LEVELS = %w[info warning error].freeze
  GUIDANCE_LOCATIONS = %w[interstitial results question].freeze

  plugin :timestamps, update_on_create: true
  plugin :auto_validations, not_null: :presence
  plugin :has_paper_trail
  skip_auto_validations(:not_null)

  dataset_module do
    def search(query)
      return self if query.blank?

      where(
        Sequel.ilike(:term, "%#{query}%") |
          Sequel.ilike(Sequel.function(:array_to_string, :aliases, ' '), "%#{query}%"),
      )
    end

    def for_source(source)
      return self if source.blank?

      where(Sequel.lit('? = ANY(sources)', source))
    end

    def matching_excluded(value)
      return self if value.blank?

      where(excluded: ActiveModel::Type::Boolean.new.cast(value))
    end

    def with_filtering(enabled)
      return self unless boolean_filter_enabled?(enabled)

      where(Sequel.lit('COALESCE(array_length(filter_prefixes, 1), 0) > 0'))
    end

    def with_escalation(enabled)
      return self unless boolean_filter_enabled?(enabled)

      where(escalate_to_webchat: true)
    end

    def with_guidance(enabled)
      return self unless boolean_filter_enabled?(enabled)

      where(Sequel.lit("COALESCE(message, '') <> ''"))
    end

    def with_excluded(enabled)
      return self unless boolean_filter_enabled?(enabled)

      where(excluded: true)
    end

    def boolean_filter_enabled?(value)
      ActiveModel::Type::Boolean.new.cast(value)
    end
  end

  def self.for_search(query, source:)
    return nil if query.blank?

    normalised_query = normalize_alias(query)

    for_source(source)
      .where(
        Sequel.ilike(:term, normalised_query) |
          Sequel.lit('aliases @> ARRAY[?]::text[]', normalised_query),
      )
      .first
  end

  def self.normalize_alias(value)
    value.to_s.squish.downcase
  end

  def aliases_array
    Array(aliases).compact_blank
  end

  def filter_prefixes_array
    Array(filter_prefixes).compact_blank
  end

  def filtering?
    filter_prefixes_array.present?
  end

  def search_metadata
    {
      term: term,
      excluded: excluded,
      filtering: filtering?,
      filter_prefixes: filter_prefixes_array,
      message: message,
      message_header: message_header,
      guidance_level: guidance_level,
      guidance_location: guidance_location,
      escalate_to_webchat: escalate_to_webchat,
    }
  end

  def validate
    super
    validates_presence :term
    validates_includes [true, false], :excluded
    validates_includes [true, false], :escalate_to_webchat
    validates_includes GUIDANCE_LEVELS, :guidance_level, allow_nil: true
    validates_includes GUIDANCE_LOCATIONS, :guidance_location, allow_nil: true

    validate_filter_prefixes
    validate_aliases
    validate_unique_search_terms
    validate_guidance_dependencies
    validates_unique :term
  end

  def before_validation
    self.term = self.class.normalize_alias(term) if term.present?
    self.aliases = Sequel.pg_array(Array(aliases).map { |value| self.class.normalize_alias(value) }.uniq, :text)

    super
  end

  private

  def validate_filter_prefixes
    prefixes = Array(filter_prefixes)
    return if prefixes.empty?

    errors.add(:filter_prefixes, 'cannot be set when excluded') if excluded
    errors.add(:filter_prefixes, 'cannot contain blank prefixes') if prefixes.any?(&:blank?)
    errors.add(:filter_prefixes, 'must contain only numeric prefixes') if prefixes.any? { |prefix| prefix.present? && !/\A\d+\z/.match?(prefix) }
  end

  def validate_aliases
    raw_aliases = Array(aliases)
    aliases = raw_aliases.compact_blank

    errors.add(:aliases, 'cannot contain blank aliases') if raw_aliases.any?(&:blank?)
    errors.add(:aliases, 'cannot duplicate the search term') if term.present? && aliases.include?(term)
  end

  def validate_unique_search_terms
    term_conflicts = []
    alias_conflicts = []

    search_terms.each do |search_term|
      conflict = search_term_conflict(search_term)
      next if conflict.blank?

      search_term == term ? term_conflicts << search_term : alias_conflicts << search_term
    end

    term_conflicts.each { |search_term| errors.add(:term, "is already used by another description intercept (#{search_term})") }
    add_alias_conflict_error(alias_conflicts)
  end

  def validate_guidance_dependencies
    errors.add(:guidance_level, 'requires message') if guidance_level.present? && message.blank?
    errors.add(:guidance_location, 'requires message') if guidance_location.present? && message.blank?
  end

  def search_terms
    ([term] + aliases_array).compact_blank
  end

  def search_term_conflict(search_term)
    query = Sequel.expr(term: search_term) | Sequel.lit('aliases @> ARRAY[?]::text[]', search_term)
    dataset = self.class.where(query)
    dataset = dataset.exclude(id:) if id.present?
    dataset.first
  end

  def add_alias_conflict_error(alias_conflicts)
    return if alias_conflicts.empty?

    message = if alias_conflicts.one?
                "include a value already used by another description intercept (#{alias_conflicts.first})"
              else
                "include values already used by another description intercept (#{alias_conflicts.join(', ')})"
              end

    errors.add(:aliases, message)
  end
end
