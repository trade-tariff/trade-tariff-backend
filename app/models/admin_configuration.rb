class AdminConfiguration < Sequel::Model(Sequel[:admin_configurations].qualify(:uk))
  plugin :oplog, primary_key: :name, materialized: true,
                 oplog_table: Sequel[:admin_configurations_oplog].qualify(:uk)
  plugin :auto_validations, not_null: :presence

  set_primary_key [:name]
  unrestrict_primary_key

  CACHE_TTL = 150.seconds

  dataset_module do
    def classification
      where(area: 'classification')
    end

    def by_name(config_name)
      Rails.cache.fetch("admin_configurations/#{config_name}", expires_in: CACHE_TTL) do
        where(name: config_name).first
      end
    end
  end

  def self.schema_type_class(column)
    return nil if column == :value

    super
  end

  def validate
    super
    validates_presence :name
    validates_presence :config_type
    validates_presence :area
    validates_presence :description
    validates_includes %w[string markdown boolean options integer], :config_type
    validate_unique_name if new?
    validate_value_for_type
  end

  def before_validation
    self.operation_date ||= Time.zone.today
    self.area ||= 'classification'
    @raw_value = self[:value]
    normalize_value!
    super
  end

  def save_with_refresh
    if save(raise_on_failure: false)
      self.class.refresh!(concurrently: false)
      true
    else
      false
    end
  end

  # Returns the selected value for 'options' type configs
  # Falls back to default if value is nil or not hash-like
  def selected_option(default: nil)
    val = self[:value]
    return default if val.blank?

    hash = case val
           when Hash then val
           when Sequel::Postgres::JSONBHash then val
           else return default
           end

    hash['selected'].presence || default
  end

  # Returns boolean value for 'boolean' type configs
  # Falls back to default if value is nil
  def enabled?(default: true)
    val = self[:value]
    return default if val.nil?

    val == true
  end

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

  def validate_unique_name
    if self.class.where(name: name).any?
      errors.add(:name, t('name.already_taken'))
    end
  end

  def t(key)
    I18n.t("sequel.errors.models.admin_configuration.#{key}")
  end

  def normalize_value!
    val = self[:value]
    return if val.nil?
    return if val.is_a?(Sequel::Postgres::JSONBObject)

    wrapped = case config_type
              when 'boolean'
                val.to_s.downcase == 'true'
              when 'integer'
                val.to_i
              when 'options'
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
    else { 'selected' => '', 'options' => [] }
    end
  rescue JSON::ParserError
    { 'selected' => '', 'options' => [] }
  end
end
