class AdminConfiguration < Sequel::Model(Sequel[:admin_configurations].qualify(:uk))
  include ValueNormalizer
  include ValueValidator

  CACHE_TTL = 150.seconds

  NESTED_OPTION_DEFAULTS = {
    'expand_model' => {
      selected: 'gpt-4.1-mini-2025-04-14',
      sub_values: {},
    },
    'label_model' => {
      selected: 'gpt-5.4',
      sub_values: { 'reasoning_effort' => 'high' },
    },
    'search_model' => {
      selected: 'gpt-5.4',
      sub_values: { 'reasoning_effort' => 'medium' },
    },
    'other_self_text_model' => {
      selected: 'gpt-5.4',
      sub_values: { 'reasoning_effort' => 'high' },
    },
    'non_other_self_text_model' => {
      selected: 'gpt-5.4',
      sub_values: { 'reasoning_effort' => 'high' },
    },
  }.freeze

  GENERIC_DESCRIPTION_INTERCEPT_MESSAGE = <<~MARKDOWN.strip.freeze
    To find the relevant commodity code, we need more information about the product.

    ## What information is needed?

    The kind of details about the product you should include are:

    - the type of product
    - what the product is used for
    - the materials used to make it
    - how it's produced
    - how it's packaged

    ## Where can I find this information?

    This information might be found on:

    - invoice or other billing documents
    - online listings
    - product information documents included in the packaging

    ## What if I need more help?

    Guidance on classifying products can be found in [help on using the tariff (opens in new tab)](https://www.gov.uk/guidance/classification-of-goods/) where you can find information about:

    - structure of commodity codes
    - the information you need to classify a product
    - detailed guidance on hard to classify products

    ## Next steps

    Go back and add more details so we can find the relevant commodity code with the highest accuracy.
  MARKDOWN

  ESCALATION_DESCRIPTION_INTERCEPT_MESSAGE = <<~MARKDOWN.strip.freeze
    The product you're searching for is difficult to classify.

    ## Next steps

    You should contact HMRC for help classifying this product.

    **Webchat:** [Ask HMRC online]({{webchat_url}})

    **Email:** [{{enquiries_email}}](mailto:{{enquiries_email}})
  MARKDOWN

  DEFAULTS = {
    'description_intercept_templates' => {
      'generic' => {
        'label' => 'Generic guidance',
        'description' => 'Use when more detail is needed before a commodity code can be suggested.',
        'attributes' => {
          'escalate_to_webchat' => false,
          'excluded' => true,
          'filter_prefixes' => [],
          'guidance_level' => 'info',
          'guidance_location' => 'interstitial',
          'message_header' => "We can't suggest a tariff code yet",
          'message' => GENERIC_DESCRIPTION_INTERCEPT_MESSAGE,
          'sources' => %w[guided_search fpo_search],
        },
      },
      'escalation' => {
        'label' => 'Escalation guidance',
        'description' => 'Use when HMRC support is needed to classify the product.',
        'attributes' => {
          'escalate_to_webchat' => true,
          'excluded' => true,
          'filter_prefixes' => [],
          'guidance_level' => 'info',
          'guidance_location' => 'interstitial',
          'message_header' => 'Contact HMRC for help',
          'message' => ESCALATION_DESCRIPTION_INTERCEPT_MESSAGE,
          'sources' => %w[guided_search fpo_search],
        },
      },
    },
    'expand_search_enabled' => false,
    'expand_search_min_results' => 5,
    'expand_search_min_score' => 5,
    'expand_search_when_needed_enabled' => false,
    'search_compressed_notes_enabled' => false,
    'expand_model' => NESTED_OPTION_DEFAULTS['expand_model'][:selected],
    'interactive_search_enabled' => true,
    'interactive_search_excluded_chapters' => %w[98 99].freeze,
    'interactive_search_max_questions' => 7,
    'refine_search_with_answers_enabled' => false,
    'label_model' => NESTED_OPTION_DEFAULTS['label_model'][:selected],
    'label_page_size' => -> { TradeTariffBackend.goods_nomenclature_label_page_size },
    'opensearch_result_limit' => 50,
    'pos_noun_boost' => 10,
    'pos_qualifier_boost' => 3,
    'pos_search_enabled' => true,
    'search_labels_enabled' => true,
    'search_non_declarables' => false,
    'search_model' => NESTED_OPTION_DEFAULTS['search_model'][:selected],
    'search_result_limit' => 0,
    'suggest_results_limit' => 10,
    'suggest_chemical_cas' => false,
    'suggest_chemical_cus' => false,
    'suggest_chemical_names' => false,
    'suggest_colloquial_terms' => false,
    'suggest_known_brands' => false,
    'suggest_synonyms' => false,
    'input_sanitiser_enabled' => true,
    'input_sanitiser_max_length' => 1000,
    'retrieval_method' => 'hybrid',
    'rrf_k' => 60,
    'vector_ef_search' => 100,
    'vector_score_threshold' => 35,
    'other_self_text_model' => NESTED_OPTION_DEFAULTS['other_self_text_model'][:selected],
    'other_self_text_batch_size' => 5,
    'non_other_self_text_model' => NESTED_OPTION_DEFAULTS['non_other_self_text_model'][:selected],
    'non_other_self_text_batch_size' => 15,
  }.freeze

  plugin :auto_validations, not_null: :presence
  plugin :has_paper_trail
  plugin :timestamps, update_on_create: true

  set_primary_key [:name]
  unrestrict_primary_key

  dataset_module do
    def classification
      where(area: 'classification')
    end

    def by_name(config_name)
      if TradeTariffBackend.environment.production?
        Rails.cache.fetch("admin_configurations/#{config_name}", expires_in: CACHE_TTL) do
          where(name: config_name).first
        end
      else
        where(name: config_name).first
      end
    end
  end

  def self.default_for(name)
    name = name.to_s
    value = DEFAULTS.fetch(name)
    value.respond_to?(:call) ? value.call : value
  end

  def self.nested_option_default_for(name)
    default = NESTED_OPTION_DEFAULTS.fetch(name.to_s)

    {
      selected: default[:selected],
      sub_values: default[:sub_values].dup,
    }
  end

  def self.enabled?(name)
    config = classification.by_name(name.to_s)
    return default_for(name) if config.nil?

    config.enabled?(default: default_for(name))
  end

  def self.integer_value(name)
    config = classification.by_name(name.to_s)
    return default_for(name).to_i if config.nil?

    config.value&.to_i || default_for(name).to_i
  end

  def self.option_value(name)
    config = classification.by_name(name.to_s)
    default = default_for(name)
    return default if config.nil?

    config.selected_option(default: default) || default
  end

  def self.multi_options_values(name)
    config = classification.by_name(name.to_s)
    default = Array(default_for(name))
    return default if config.nil?

    val = config[:value]
    hash = case val
           when Hash then val
           when Sequel::Postgres::JSONBHash then val.to_hash
           else {}
           end

    selected = hash['selected']
    selected.is_a?(Array) ? selected : default
  end

  def self.nested_options_value(name)
    config = classification.by_name(name.to_s)
    nested_default = NESTED_OPTION_DEFAULTS[name.to_s]
    default_value = default_for(name)

    if config.nil?
      selected = nested_default&.fetch(:selected, default_value) || default_value

      return {
        selected: selected,
        sub_values: supported_nested_sub_values(selected, nested_default&.fetch(:sub_values, {}) || {}),
      }
    end

    val = config[:value]
    hash = case val
           when Hash then val
           when Sequel::Postgres::JSONBHash then val.to_hash
           else {}
           end

    selected = hash['selected'].presence || default_value

    {
      selected: selected,
      sub_values: supported_nested_sub_values(selected, hash['sub_values'].is_a?(Hash) ? hash['sub_values'] : {}),
    }
  end

  def self.supported_nested_sub_values(selected, sub_values)
    return {} unless sub_values.is_a?(Hash)

    model_config = OpenaiClient::MODEL_CONFIGS[selected.to_s]
    return sub_values if model_config.nil?

    allowed = {}
    if model_config[:reasoning_levels].present? && model_config[:reasoning_levels].include?(sub_values['reasoning_effort'])
      allowed['reasoning_effort'] = sub_values['reasoning_effort']
    end

    allowed
  end

  def self.description_intercept_templates_value
    config = classification.by_name('description_intercept_templates')
    val = config&.value || default_for('description_intercept_templates')

    case val
    when Hash then val
    when Sequel::Postgres::JSONBHash then val.to_hash
    else default_for('description_intercept_templates')
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
    validates_includes %w[string markdown boolean options multi_options integer nested_options object_template], :config_type
    validate_unique_name if new?
    validate_value_for_type
  end

  def before_validation
    self.area ||= 'classification'
    @raw_value = self[:value]
    normalize_value!
    super
  end

  def after_save
    super
    clear_expand_search_cache_if_needed
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

  def validate_unique_name
    if self.class.where(name: name).any?
      errors.add(:name, t('name.already_taken'))
    end
  end

  def t(key)
    I18n.t("sequel.errors.models.admin_configuration.#{key}")
  end

  def clear_expand_search_cache_if_needed
    return unless %w[expand_query_context expand_model].include?(name)

    ExpandSearchQueryService.clear_cache!
  end
end
