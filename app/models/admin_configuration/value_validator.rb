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
      when 'multi_options'
        validate_multi_options_value
      when 'nested_options'
        validate_nested_options_value
      when 'object_template'
        validate_object_template_value
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

    def validate_multi_options_value
      val = self[:value]
      return if val.nil?

      hash = case val
             when Hash then val
             when Sequel::Postgres::JSONBHash then val.to_hash
             when Sequel::Postgres::JSONBObject then return
             else return errors.add(:value, t('value.invalid_options'))
             end

      options = hash['options']
      unless options.is_a?(Array) && options.any?
        errors.add(:value, t('value.no_options'))
        return
      end

      selected = hash['selected']
      unless selected.is_a?(Array)
        errors.add(:value, t('value.invalid_options'))
        return
      end

      option_keys = options.filter_map { |option| option['key'] if option.is_a?(Hash) }
      errors.add(:value, t('value.invalid_options')) unless (selected - option_keys).empty?
    end

    def validate_object_template_value
      templates = hash_value
      return errors.add(:value, 'must be a map of object templates') unless templates.is_a?(Hash) && templates.present?

      templates.each do |key, template|
        unless key.to_s.match?(/\A[a-z][a-z0-9_]*\z/)
          errors.add(:value, 'template keys must be lowercase snake case')
          next
        end

        validate_object_template(key, template)
      end
    end

    def validate_object_template(key, template)
      unless template.is_a?(Hash) && template.keys.sort == %w[attributes description label]
        errors.add(:value, "#{key} must include label, description and attributes")
        return
      end

      errors.add(:value, "#{key} label is required") if template['label'].blank?
      errors.add(:value, "#{key} description is required") if template['description'].blank?

      attrs = template['attributes']
      unless attrs.is_a?(Hash)
        errors.add(:value, "#{key} attributes must be a map")
      end
    end

    def hash_value
      val = self[:value]
      case val
      when Hash then val
      when Sequel::Postgres::JSONBHash then val.to_hash
      end
    end
  end
end
