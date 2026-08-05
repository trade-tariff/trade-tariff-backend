require 'digest'

module VatGuidance
  class GuideVersion < Sequel::Model(:vat_guide_versions)
    include ImmutableRecord

    SHA256_PATTERN = /\A[0-9a-f]{64}\z/
    SECTION_KEYS = %w[section_key heading content content_sha256].freeze

    plugin :auto_validations
    plugin :timestamps

    many_to_one :guide,
                class: 'VatGuidance::Guide',
                key: :guide_id

    def validate
      super
      validates_presence %i[guide_id title canonical_path source_url language captured_at body_sha256]
      errors.add(:body_sha256, 'must be a lowercase SHA-256 digest') unless body_sha256.to_s.match?(SHA256_PATTERN)
      validate_sections
      errors.add(:capture_metadata, 'must be an object') unless capture_metadata.respond_to?(:to_hash)
    end

  private

    def validate_sections
      unless sections.respond_to?(:to_ary)
        errors.add(:sections, 'must be an array')
        return
      end

      section_keys = sections.to_a.filter_map.with_index do |section, index|
        validate_section(section, index)
      end
      errors.add(:sections, 'must have unique section keys') if section_keys.uniq.length != section_keys.length
    end

    def validate_section(section, index)
      unless section.respond_to?(:to_hash)
        errors.add(:sections, "entry #{index + 1} must be an object")
        return
      end

      section = section.to_hash.stringify_keys
      unknown_keys = section.keys - SECTION_KEYS
      errors.add(:sections, "entry #{index + 1} has unknown fields: #{unknown_keys.join(', ')}") if unknown_keys.any?

      section_key = section['section_key']
      unless section_key.is_a?(String) && section_key.present?
        errors.add(:sections, "entry #{index + 1} section_key must be a non-empty string")
      end

      validate_optional_string(section, 'heading', index)
      validate_optional_string(section, 'content', index)
      validate_section_content(section, index)

      section_key if section_key.is_a?(String) && section_key.present?
    end

    def validate_optional_string(section, key, index)
      return unless section.key?(key) && !section[key].is_a?(String)

      errors.add(:sections, "entry #{index + 1} #{key} must be a string")
    end

    def validate_section_content(section, index)
      content = section['content']
      content_sha256 = section['content_sha256']

      if content.blank? && content_sha256.blank?
        errors.add(:sections, "entry #{index + 1} must have content or content_sha256")
      end

      return if content_sha256.blank?

      unless content_sha256.is_a?(String) && content_sha256.match?(SHA256_PATTERN)
        errors.add(:sections, "entry #{index + 1} content_sha256 must be a lowercase SHA-256 digest")
        return
      end

      return unless content.is_a?(String) && Digest::SHA256.hexdigest(content) != content_sha256

      errors.add(:sections, "entry #{index + 1} content_sha256 must match content")
    end
  end
end
