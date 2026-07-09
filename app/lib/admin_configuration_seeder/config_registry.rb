require_relative 'prompt_registry'

module AdminConfigurationSeeder
  module ConfigRegistry
    CONFIG_PATH = Pathname.new(__dir__).join('configs.yml').freeze

  module_function

    def configs
      YAML.safe_load_file(CONFIG_PATH).map { |definition| materialize_config(definition) }
    end

    def materialize_config(definition)
      attrs = definition.transform_keys(&:to_sym)
      value = config_value(attrs)
      attrs.except(:default, :string_default, :prompt, :nested_option, :chapter_options, :retrieval_method_options)
           .merge(value:)
    end

    def config_value(attrs)
      return AdminConfiguration.default_for(attrs[:default]) if attrs[:default]
      return AdminConfiguration.default_for(attrs[:string_default]).to_s if attrs[:string_default]
      return PromptRegistry.prompt("#{attrs[:prompt]}_markdown".to_sym) if attrs[:prompt]
      return nested_option_value(attrs[:nested_option]) if attrs[:nested_option]
      return chapter_options_value if attrs[:chapter_options]
      return retrieval_method_value if attrs[:retrieval_method_options]

      attrs[:value]
    end

    def model_options_with_reasoning
      @model_options_with_reasoning ||= OpenaiClient::MODEL_CONFIGS.keys.sort.map do |key|
        levels = OpenaiClient::MODEL_CONFIGS[key][:reasoning_levels]
        {
          'key' => key,
          'label' => PromptRegistry.model_label(key),
          'sub_options' => levels.any? ? { 'reasoning_effort' => levels } : {},
        }
      end
    end

    def nested_option_value(name)
      default = AdminConfiguration.nested_option_default_for(name)
      {
        'selected' => default[:selected],
        'sub_values' => default[:sub_values],
        'options' => model_options_with_reasoning,
      }
    end

    def chapter_options_value
      {
        'selected' => AdminConfiguration.default_for('interactive_search_excluded_chapters'),
        'options' => (1..99).map { |chapter| chapter_option(chapter) },
      }
    end

    def chapter_option(chapter)
      formatted = sprintf('%02d', chapter)
      { 'key' => formatted, 'label' => "Chapter #{formatted}" }
    end

    def retrieval_method_value
      {
        'selected' => AdminConfiguration.default_for('retrieval_method'),
        'options' => [
          { 'key' => 'opensearch', 'label' => 'OpenSearch (text search)' },
          { 'key' => 'vector', 'label' => 'pgvector (cosine similarity)' },
          { 'key' => 'hybrid', 'label' => 'Hybrid (text + vector with RRF fusion)' },
        ],
      }
    end
  end
end
