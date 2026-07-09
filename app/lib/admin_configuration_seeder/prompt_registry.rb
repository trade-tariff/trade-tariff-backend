module AdminConfigurationSeeder
  module PromptRegistry
    PROMPT_PATH = Pathname.new(__dir__).join('prompts').freeze

    MODEL_LABELS = {
      'gpt-4.1-2025-04-14' => 'GPT-4.1 (1M context)',
      'gpt-4.1-mini-2025-04-14' => 'GPT-4.1 mini (1M context)',
      'gpt-4.1-nano-2025-04-14' => 'GPT-4.1 nano (1M context)',
      'gpt-4o' => 'GPT-4o (multimodal)',
      'gpt-4o-mini' => 'GPT-4o mini',
      'gpt-5-2025-08-07' => 'GPT-5 (base)',
      'gpt-5-mini-2025-08-07' => 'GPT-5 mini (fast)',
      'gpt-5-nano-2025-08-07' => 'GPT-5 nano (fastest)',
      'gpt-5.1-2025-11-13' => 'GPT-5.1 (extended caching & coding)',
      'gpt-5.2' => 'GPT-5.2',
      'gpt-5.4' => 'GPT-5.4',
      'gpt-5.5' => 'GPT-5.5 (latest flagship)',
      'o3-2025-04-16' => 'o3 (full reasoning)',
      'o3-pro' => 'o3-pro (complex reasoning)',
      'o4-mini-2025-04-16' => 'o4-mini (small reasoning)',
    }.freeze

    PROMPT_FILES = {
      atar_fact_context_markdown: 'atar_fact_context.md',
      duplicate_question_guard_context_markdown: 'duplicate_question_guard_context.md',
      expand_query_context_markdown: 'expand_query_context.md',
      label_context_markdown: 'label_context.md',
      non_other_self_text_context_markdown: 'non_other_self_text_context.md',
      other_self_text_context_markdown: 'other_self_text_context.md',
      search_context_markdown: 'search_context.md',
    }.freeze

  module_function

    def model_label(key)
      MODEL_LABELS.fetch(key, key)
    end

    def prompt(name)
      PROMPT_PATH.join(PROMPT_FILES.fetch(name)).read.strip
    end
  end
end
