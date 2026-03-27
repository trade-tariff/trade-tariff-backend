# frozen_string_literal: true

class AdminConfiguration
  # Validates that the stored value is structurally correct for its
  # config_type. Included as a private mixin on AdminConfiguration; not
  # intended for use outside that class.
  module ValueValidator
    private

    def validate_value_for_type
      return if config_type.blank?

      case config_type
      when 'boolean'
        validate_boolean_value
      when 'integer'
        validate_integer_value
      when 'options'
        validate_options_value
      when 'nested_options'
        validate_nested_options_value
      when 'string', 'markdown'
        validate_text_value
      end
    end

    def validate_boolean_value
      normalized = self[:value]
      return if normalized.nil?
      return if normalized.is_a?(Sequel::Postgres::JSONBObject)

      errors.add(:value, t('value.invalid_boolean')) unless [true, false].include?(normalized)
    end

    def validate_integer_value
      val = @raw_value
      return if val.nil?
      return if val.is_a?(Sequel::Postgres::JSONBObject)

      errors.add(:value, t('value.invalid_integer')) unless val.to_s.match?(/\A-?\d+\z/)
    end

    def validate_text_value
      val = self[:value]
      return if val.is_a?(Sequel::Postgres::JSONBObject)

      errors.add(:value, t('value.blank')) if val.blank?
    end

    def validate_options_value
      val = self[:value]
      return if val.nil?

      hash = case val
             when Hash then val
             when Sequel::Postgres::JSONBHash then val.to_hash
             when Sequel::Postgres::JSONBObject then return
             else return errors.add(:value, t('value.invalid_options'))
             end

      options = hash['options']
      errors.add(:value, t('value.no_options')) unless options.is_a?(Array) && options.any?
    end

    def validate_nested_options_value
      val = self[:value]
      return if val.nil?

      hash = case val
             when Hash then val
             when Sequel::Postgres::JSONBHash then val.to_hash
             when Sequel::Postgres::JSONBObject then return
             else return errors.add(:value, t('value.invalid_nested_options'))
             end

      options = hash['options']
      errors.add(:value, t('value.no_options')) unless options.is_a?(Array) && options.any?

      selected = hash['selected']
      errors.add(:value, t('value.no_selected')) if selected.blank?
    end
  end
end
