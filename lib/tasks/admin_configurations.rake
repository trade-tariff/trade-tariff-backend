require_relative '../../app/lib/admin_configuration_seeder'

namespace :admin_configurations do
  # Seed values should align with AdminConfiguration::DEFAULTS
  desc 'Seed initial admin configurations'
  task seed: :environment do
    model_options_with_reasoning = OpenaiClient::MODEL_CONFIGS.keys.sort.map do |key|
      levels = OpenaiClient::MODEL_CONFIGS[key][:reasoning_levels]
      {
        'key' => key,
        'label' => AdminConfigurationSeeder.model_label(key),
        'sub_options' => levels.any? ? { 'reasoning_effort' => levels } : {},
      }
    end

    nested_option_value = lambda do |name|
      default = AdminConfiguration.nested_option_default_for(name)
      {
        'selected' => default[:selected],
        'sub_values' => default[:sub_values],
        'options' => model_options_with_reasoning,
      }
    end

    chapter_options = lambda do
      (1..99).map do |chapter|
        formatted = sprintf('%02d', chapter)
        { 'key' => formatted, 'label' => "Chapter #{formatted}" }
      end
    end

    configs = [
      {
        name: 'description_intercept_templates',
        config_type: 'object_template',
        description: 'Named templates used by the description intercept bulk import. CSV uploads provide term and template only.',
        value: AdminConfiguration.default_for('description_intercept_templates'),
      },
      {
        name: 'expand_search_enabled',
        config_type: 'boolean',
        description: 'Expand search queries using AI to translate everyday language into tariff terminology before searching',
        value: AdminConfiguration.default_for('expand_search_enabled'),
      },
      {
        name: 'expand_search_when_needed_enabled',
        config_type: 'boolean',
        description: 'Requires expand_search_enabled. Only expand search queries when simple heuristics suggest expansion is useful: acronym-like terms, no useful word parts from POS tagging, low result count, or low top score from weak retrieval results',
        value: AdminConfiguration.default_for('expand_search_when_needed_enabled'),
      },
      {
        name: 'expand_search_min_results',
        config_type: 'integer',
        description: 'Minimum number of retrieval results required before conditional query expansion is skipped',
        value: AdminConfiguration.default_for('expand_search_min_results').to_s,
      },
      {
        name: 'expand_search_min_score',
        config_type: 'integer',
        description: 'Minimum top retrieval score required before conditional query expansion is skipped',
        value: AdminConfiguration.default_for('expand_search_min_score').to_s,
      },
      {
        name: 'expand_model',
        config_type: 'nested_options',
        description: 'AI model used for search query expansion',
        value: nested_option_value.call('expand_model'),
      },
      {
        name: 'expand_query_context',
        config_type: 'markdown',
        description: 'System prompt sent to the AI model when expanding search queries',
        value: AdminConfigurationSeeder.expand_query_context_markdown,
      },
      {
        name: 'search_compressed_notes_enabled',
        config_type: 'boolean',
        description: 'Include current approved compressed notes in the internal search LLM context. Only enable this in staging.',
        value: AdminConfiguration.default_for('search_compressed_notes_enabled'),
      },
      {
        name: 'interactive_search_enabled',
        config_type: 'boolean',
        description: 'Enable interactive Q&A to help traders narrow down commodity codes through clarifying questions',
        value: AdminConfiguration.default_for('interactive_search_enabled'),
      },
      {
        name: 'interactive_search_duplicate_question_guard_enabled',
        config_type: 'boolean',
        description: 'Detect and retry repeated interactive search questions before showing them to traders',
        value: AdminConfiguration.default_for('interactive_search_duplicate_question_guard_enabled'),
      },
      {
        name: 'interactive_search_duplicate_question_guard_context',
        config_type: 'markdown',
        description: 'System prompt sent to the cheap AI model when validating whether a suspicious interactive search question repeats an already answered classification distinction',
        value: AdminConfigurationSeeder.duplicate_question_guard_context_markdown,
      },
      {
        name: 'interactive_search_duplicate_question_guard_model',
        config_type: 'nested_options',
        description: 'Cheap AI model used to validate whether a suspicious interactive search question repeats an already answered classification distinction',
        value: nested_option_value.call('interactive_search_duplicate_question_guard_model'),
      },
      {
        name: 'interactive_search_excluded_chapters',
        config_type: 'multi_options',
        description: 'Chapters excluded from guided search results',
        value: {
          'selected' => AdminConfiguration.default_for('interactive_search_excluded_chapters'),
          'options' => chapter_options.call,
        },
      },
      {
        name: 'interactive_search_max_questions',
        config_type: 'integer',
        description: 'Maximum number of clarifying questions to ask before forcing a best-guess answer from the AI',
        value: AdminConfiguration.default_for('interactive_search_max_questions').to_s,
      },
      {
        name: 'refine_search_with_answers_enabled',
        config_type: 'boolean',
        description: 'Append answered interactive search question values to the retrieval query so each iteration targets the shortlist more closely',
        value: AdminConfiguration.default_for('refine_search_with_answers_enabled'),
      },
      {
        name: 'input_sanitiser_enabled',
        config_type: 'boolean',
        description: 'Sanitise and validate search queries before AI processing. Strips HTML, rejects non-printable characters, and enforces a maximum query length.',
        value: AdminConfiguration.default_for('input_sanitiser_enabled'),
      },
      {
        name: 'input_sanitiser_max_length',
        config_type: 'integer',
        description: 'Maximum allowed character length for search queries when input sanitiser is enabled',
        value: AdminConfiguration.default_for('input_sanitiser_max_length').to_s,
      },
      {
        name: 'retrieval_method',
        config_type: 'options',
        description: 'Search retrieval method: opensearch uses traditional text search, ' \
          'vector uses pgvector cosine similarity, and hybrid runs both and fuses with RRF. ' \
          'Query expansion runs before the selected retrieval method.',
        value: { 'selected' => AdminConfiguration.default_for('retrieval_method'),
                 'options' => [
                   { 'key' => 'opensearch', 'label' => 'OpenSearch (text search)' },
                   { 'key' => 'vector', 'label' => 'pgvector (cosine similarity)' },
                   { 'key' => 'hybrid', 'label' => 'Hybrid (text + vector with RRF fusion)' },
                 ] },
      },
      {
        name: 'rrf_k',
        config_type: 'integer',
        description: 'Reciprocal Rank Fusion constant (k). Controls how much lower-ranked results are penalised: score = 1/(rank + k). Higher k flattens rank differences. Typical range 1-100. Only applies when retrieval_method is hybrid.',
        value: AdminConfiguration.default_for('rrf_k').to_s,
      },
      {
        name: 'vector_ef_search',
        config_type: 'integer',
        description: 'HNSW ef_search parameter for pgvector queries. Controls the recall/speed tradeoff: higher values search more candidates and improve recall at the cost of latency. Typical range 40-200. Only applies when retrieval_method is vector.',
        value: AdminConfiguration.default_for('vector_ef_search').to_s,
      },
      {
        name: 'vector_score_threshold',
        config_type: 'integer',
        description: 'Minimum cosine similarity score (0-100) for vector search results. Results below this threshold are discarded before AI processing. Based on empirical analysis: good queries score 47-70, junk queries score 13-35. Default 35 provides clean separation.',
        value: AdminConfiguration.default_for('vector_score_threshold').to_s,
      },
      {
        name: 'label_context',
        config_type: 'markdown',
        description: 'System prompt sent to the AI model when labelling commodities',
        value: AdminConfigurationSeeder.label_context_markdown,
      },
      {
        name: 'label_model',
        config_type: 'nested_options',
        description: 'AI model used for commodity labelling',
        value: nested_option_value.call('label_model'),
      },
      {
        name: 'label_page_size',
        config_type: 'integer',
        description: 'Number of commodities processed per batch during AI labelling',
        value: AdminConfiguration.default_for('label_page_size').to_s,
      },
      {
        name: 'opensearch_result_limit',
        config_type: 'integer',
        description: 'Maximum number of OpenSearch results fetched for AI processing during interactive search',
        value: AdminConfiguration.default_for('opensearch_result_limit').to_s,
      },
      {
        name: 'pos_noun_boost',
        config_type: 'integer',
        description: 'Boost factor for nouns in POS-tagged search queries. Higher values make noun matches dominate scoring.',
        value: AdminConfiguration.default_for('pos_noun_boost').to_s,
      },
      {
        name: 'pos_qualifier_boost',
        config_type: 'integer',
        description: 'Boost factor for qualifiers (adjectives, past participles, gerunds) in POS-tagged search queries.',
        value: AdminConfiguration.default_for('pos_qualifier_boost').to_s,
      },
      {
        name: 'pos_search_enabled',
        config_type: 'boolean',
        description: 'Use part-of-speech tagging to structure search queries. Nouns become required terms, modifiers become optional. When disabled, falls back to a single multi-match query.',
        value: AdminConfiguration.default_for('pos_search_enabled'),
      },
      {
        name: 'other_self_text_batch_size',
        config_type: 'integer',
        description: 'Number of Other nodes processed per batch during AI self-text generation',
        value: AdminConfiguration.default_for('other_self_text_batch_size').to_s,
      },
      {
        name: 'other_self_text_context',
        config_type: 'markdown',
        description: 'System prompt sent to the AI model when generating self-texts for Other nodes',
        value: AdminConfigurationSeeder.other_self_text_context_markdown,
      },
      {
        name: 'other_self_text_model',
        config_type: 'nested_options',
        description: 'AI model used for generating self-texts for Other nodes',
        value: nested_option_value.call('other_self_text_model'),
      },
      {
        name: 'non_other_self_text_batch_size',
        config_type: 'integer',
        description: 'Number of non-Other nodes processed per batch during AI self-text generation',
        value: AdminConfiguration.default_for('non_other_self_text_batch_size').to_s,
      },
      {
        name: 'non_other_self_text_context',
        config_type: 'markdown',
        description: 'System prompt sent to the AI model when generating self-texts for non-Other nodes',
        value: AdminConfigurationSeeder.non_other_self_text_context_markdown,
      },
      {
        name: 'non_other_self_text_model',
        config_type: 'nested_options',
        description: 'AI model used for generating self-texts for non-Other nodes',
        value: nested_option_value.call('non_other_self_text_model'),
      },
      {
        name: 'atar_fact_context',
        config_type: 'markdown',
        description: 'System prompt sent to the AI model when extracting retrieval facts from public ATARs',
        value: AdminConfigurationSeeder.atar_fact_context_markdown,
      },
      {
        name: 'atar_fact_model',
        config_type: 'nested_options',
        description: 'AI model used for extracting retrieval facts from public ATARs',
        value: nested_option_value.call('atar_fact_model'),
      },
      {
        name: 'search_context',
        config_type: 'markdown',
        description: 'System prompt sent to the AI model during interactive search',
        value: AdminConfigurationSeeder.search_context_markdown,
      },
      {
        name: 'search_labels_enabled',
        config_type: 'boolean',
        description: 'Include AI-generated labels (brands, synonyms, colloquial terms) in search queries',
        value: AdminConfiguration.default_for('search_labels_enabled'),
      },
      {
        name: 'search_model',
        config_type: 'nested_options',
        description: 'AI model used for interactive Q&A search',
        value: nested_option_value.call('search_model'),
      },
      {
        name: 'search_result_limit',
        config_type: 'integer',
        description: 'Maximum number of commodity code suggestions shown during interactive Q&A. The frontend uses this to decide how to display results (e.g. as a shortlist or expanded view).',
        value: AdminConfiguration.default_for('search_result_limit').to_s,
      },
      {
        name: 'suggest_results_limit',
        config_type: 'integer',
        description: 'Maximum number of search suggestions returned by the internal suggestions endpoint',
        value: AdminConfiguration.default_for('suggest_results_limit').to_s,
      },
      {
        name: 'suggest_chemical_cas',
        config_type: 'boolean',
        description: 'Enable CAS Registry Number suggestions and exact match redirects in internal search',
        value: AdminConfiguration.default_for('suggest_chemical_cas'),
      },
      {
        name: 'suggest_chemical_cus',
        config_type: 'boolean',
        description: 'Enable CUS identifier suggestions and exact match redirects in internal search',
        value: AdminConfiguration.default_for('suggest_chemical_cus'),
      },
      {
        name: 'suggest_chemical_names',
        config_type: 'boolean',
        description: 'Enable chemical substance name suggestions and exact match redirects in internal search',
        value: AdminConfiguration.default_for('suggest_chemical_names'),
      },
      {
        name: 'suggest_colloquial_terms',
        config_type: 'boolean',
        description: 'Enable AI-generated colloquial term suggestions and exact match redirects in internal search',
        value: AdminConfiguration.default_for('suggest_colloquial_terms'),
      },
      {
        name: 'suggest_known_brands',
        config_type: 'boolean',
        description: 'Enable AI-generated known brand suggestions and exact match redirects in internal search',
        value: AdminConfiguration.default_for('suggest_known_brands'),
      },
      {
        name: 'suggest_synonyms',
        config_type: 'boolean',
        description: 'Enable AI-generated synonym suggestions and exact match redirects in internal search',
        value: AdminConfiguration.default_for('suggest_synonyms'),
      },
    ]

    created = 0

    configs.each do |attrs|
      config = AdminConfiguration.where(name: attrs[:name]).first
      if config
        if config.config_type != attrs[:config_type]
          config.update(config_type: attrs[:config_type], value: attrs[:value])
          puts "  patched: #{attrs[:name]} (config type)"
          created += 1
        else
          puts "  skip: #{attrs[:name]} (already exists)"
        end
        next
      end

      AdminConfiguration.create(attrs.merge(area: 'classification'))
      puts "  created: #{attrs[:name]}"
      created += 1
    end

    # Patch existing retrieval_method to include hybrid option if missing
    retrieval = AdminConfiguration.where(name: 'retrieval_method').first
    if retrieval
      options = retrieval.value['options'] || []
      unless options.any? { |o| o['key'] == 'hybrid' }
        options << { 'key' => 'hybrid', 'label' => 'Hybrid (text + vector with RRF fusion)' }
        retrieval.update(value: Sequel.pg_jsonb_wrap(retrieval.value.to_hash.merge('options' => options)))
        puts '  patched: retrieval_method (added hybrid option)'
        created += 1
      end
    end

    puts "  created #{created} configuration(s)" if created.positive?
  end

  desc 'Reset and reseed all admin configurations'
  task reseed: :environment do
    Version.where(item_type: 'AdminConfiguration').delete
    AdminConfiguration.truncate
    puts '  truncated admin configurations'

    Rake::Task['admin_configurations:seed'].invoke
  end
end
