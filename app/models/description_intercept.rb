class DescriptionIntercept < Sequel::Model
  plugin :timestamps, update_on_create: true
  plugin :auto_validations, not_null: :presence
  plugin :has_paper_trail

  def validate
    super
    validates_presence :term
    validates_presence :sources
    validates_includes [true, false], :excluded
    validates_includes [true, false], :escalate_to_webchat

    if Array(sources).empty?
      errors.add(:sources, 'is not present')
    end

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
