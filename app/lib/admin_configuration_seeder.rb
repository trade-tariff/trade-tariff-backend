require_relative 'admin_configuration_seeder/prompt_registry'

module AdminConfigurationSeeder
module_function

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
