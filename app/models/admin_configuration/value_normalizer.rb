# frozen_string_literal: true

class AdminConfiguration
  # Handles coercion of raw user-supplied values into the JSONB-wrapped type
  # appropriate for each config_type. Included as a private mixin on
  # AdminConfiguration; not intended for use outside that class.
  module ValueNormalizer
    private

    def normalize_value!
      val = self[:value]
      return if val.nil?
      return if val.is_a?(Sequel::Postgres::JSONBObject)

      wrapped = case config_type
                when 'boolean'
                  val.to_s.downcase == 'true'
                when 'integer'
                  val.to_i
                when 'options', 'nested_options', 'multi_options'
                  coerce_json_object(val)
                else # string, markdown
                  val.to_s
                end

      self[:value] = Sequel.pg_jsonb_wrap(wrapped)
    end

    def coerce_json_object(val)
      case val
      when Hash then val
      when Sequel::Postgres::JSONBHash then val.to_hash
      when String then JSON.parse(val)
      else { 'selected' => default_selected_value, 'options' => [] }
      end
    rescue JSON::ParserError
      { 'selected' => default_selected_value, 'options' => [] }
    end

    def default_selected_value
      config_type == 'multi_options' ? [] : ''
    end
  end
end
