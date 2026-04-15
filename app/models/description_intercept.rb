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

      where(Sequel.ilike(:term, "%#{query}%"))
    end

    def for_source(source)
      return self if source.blank?

      where(Sequel.lit('? = ANY(sources)', source))
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

  def validate
    super
    validates_presence :term
    validates_includes [true, false], :excluded
    validates_includes [true, false], :escalate_to_webchat
    validates_includes GUIDANCE_LEVELS, :guidance_level, allow_nil: true
    validates_includes GUIDANCE_LOCATIONS, :guidance_location, allow_nil: true

    validate_filter_prefixes
    validate_guidance_dependencies
  end

  private

  def validate_filter_prefixes
    prefixes = Array(filter_prefixes)
    return if prefixes.empty?

    errors.add(:filter_prefixes, 'cannot be set when excluded') if excluded
    errors.add(:filter_prefixes, 'cannot contain blank prefixes') if prefixes.any?(&:blank?)
    errors.add(:filter_prefixes, 'must contain only numeric prefixes') if prefixes.any? { |prefix| prefix.present? && !/\A\d+\z/.match?(prefix) }
  end

  def validate_guidance_dependencies
    errors.add(:guidance_level, 'requires message') if guidance_level.present? && message.blank?
    errors.add(:guidance_location, 'requires message') if guidance_location.present? && message.blank?
  end
end
