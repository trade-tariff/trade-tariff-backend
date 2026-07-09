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

    patch_config_type(config, attrs)
  end

  def create_config(attrs)
    AdminConfiguration.create(attrs.merge(area: 'classification'))
    output "  created: #{attrs[:name]}"
    1
  end

  def patch_config_type(config, attrs)
    if config.config_type == attrs[:config_type]
      output "  skip: #{attrs[:name]} (already exists)"
      return 0
    end

    config.update(config_type: attrs[:config_type], value: attrs[:value])
    output "  patched: #{attrs[:name]} (config type)"
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
