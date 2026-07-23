require_relative 'admin_configuration_seeder/config_registry'
require_relative 'admin_configuration_seeder/prompt_registry'

module AdminConfigurationSeeder
module_function

  def seed
    created = ConfigRegistry.configs.sum { |attrs| create_or_patch(attrs) }
    created += patch_retrieval_method

    output "  created #{created} configuration(s)" if created.positive?
  end

  def create_or_patch(attrs)
    config = AdminConfiguration.where(name: attrs[:name]).first
    return create_config(attrs) unless config

    patch_config(config, attrs)
  end

  def create_config(attrs)
    AdminConfiguration.create(attrs.merge(area: 'classification'))
    output "  created: #{attrs[:name]}"
    1
  end

  def patch_config(config, attrs)
    if config.config_type != attrs[:config_type]
      config.update(config_type: attrs[:config_type], value: attrs[:value], description: attrs[:description])
      output "  patched: #{attrs[:name]} (config type)"
      return 1
    end

    return refresh_nested_options(config, attrs) if config.config_type == 'nested_options'

    if config.description == attrs[:description]
      output "  skip: #{attrs[:name]} (already exists)"
      return 0
    end

    config.update(description: attrs[:description])
    output "  patched: #{attrs[:name]} (description)"
    1
  end

  def refresh_nested_options(config, attrs)
    value = config.value.to_hash.merge('options' => attrs[:value]['options'])
    return 0 if value == config.value.to_hash

    config.update(value: Sequel.pg_jsonb_wrap(value))
    output "  patched: #{attrs[:name]} (options)"
    1
  end

  def patch_retrieval_method
    retrieval = AdminConfiguration.where(name: 'retrieval_method').first
    return 0 unless retrieval

    options = retrieval.value['options'] || []
    return 0 if options.any? { |option| option['key'] == 'hybrid' }

    options << { 'key' => 'hybrid', 'label' => 'Hybrid (text + vector with RRF fusion)' }
    retrieval.update(value: Sequel.pg_jsonb_wrap(retrieval.value.to_hash.merge('options' => options)))
    output '  patched: retrieval_method (added hybrid option)'
    1
  end

  def output(message)
    $stdout.puts(message)
  end

  def model_label(key)
    PromptRegistry.model_label(key)
  end

  def label_context_markdown
    PromptRegistry.prompt(:label_context_markdown)
  end

  def search_context_markdown
    PromptRegistry.prompt(:search_context_markdown)
  end

  def other_self_text_context_markdown
    PromptRegistry.prompt(:other_self_text_context_markdown)
  end

  def non_other_self_text_context_markdown
    PromptRegistry.prompt(:non_other_self_text_context_markdown)
  end

  def expand_query_context_markdown
    PromptRegistry.prompt(:expand_query_context_markdown)
  end

  def duplicate_question_guard_context_markdown
    PromptRegistry.prompt(:duplicate_question_guard_context_markdown)
  end

  def atar_fact_context_markdown
    PromptRegistry.prompt(:atar_fact_context_markdown)
  end
end
