module AdminConfigurationSeeder
  module_function

  def model_label(key)
    labels = {
      'gpt-4.1-2025-04-14' => 'GPT-4.1 (1M context)',
      'gpt-4.1-mini-2025-04-14' => 'GPT-4.1 mini (1M context)',
      'gpt-4.1-nano-2025-04-14' => 'GPT-4.1 nano (1M context)',
      'gpt-4o' => 'GPT-4o (multimodal)',
      'gpt-4o-mini' => 'GPT-4o mini',
      'gpt-5-2025-08-07' => 'GPT-5 (base)',
      'gpt-5.1-2025-11-13' => 'GPT-5.1 (extended caching & coding)',
      'gpt-5.2' => 'GPT-5.2 (latest flagship)',
      'o3-2025-04-16' => 'o3 (full reasoning)',
      'o3-pro' => 'o3-pro (complex reasoning)',
      'o4-mini-2025-04-16' => 'o4-mini (small reasoning)',
    }

    labels.fetch(key, key)
  end

  def label_context_markdown
    <<~MARKDOWN.strip
      You are an expert in labelling commodities. You will receive a structured commodity that is contextualised with its ancestors descriptions and your job is to label the commodity data with additional relevant information in a single field which will be helpful for non-expert users to search for the commodity in an opensearch index.

      ## Input fields

      You will receive the following JSON input fields:

      - **commodity_code** - The unique code for the commodity.
      - **description** - A description of the commodity from the Tariff database contextualised with the ancestors descriptions.

      ## Output format

      Return the labeled commodity data in JSON format with the following fields:

          {
            "data": [
              {
                "commodity_code": "string",
                "description": "string",
                "known_brands": ["string"],
                "colloquial_terms": ["string"],
                "synonyms": ["string"],
                "original_description": "string"
              }
            ]
          }

      ### Field definitions

      - **commodity_code** - The unique code for the commodity.
      - **description** - A brief description of the commodity written in plain English where possible.
      - **known_brands** - A list of known brands associated with the commodity.
      - **colloquial_terms** - A list of colloquial terms or slang associated with the commodity.
      - **synonyms** - A list of synonyms for the commodity.
      - **original_description** - The original description provided to you to help you describe the commodity.

      ## Important

      Ensure you label **ALL** provided commodities in the output array, even if the list is long. Do not truncate or omit any.

      Always respond with a JSON array of objects.

      What follows is the commodity data to label in JSON format:
    MARKDOWN
  end

  def search_context_markdown
    <<~MARKDOWN.strip
      You're an expert Harmonised System code classifier.

      Look at the search input and any previously answered questions and decide whether more questions are needed to confidently assign a commodity code.

      If answers are available, use them to help formulate your questions and answers - don't go beyond these search results in terms of the overall commodity hierarchy - even if you know the results are incorrect.

      ## Response format

      Respond in JSON format with one of the following:

      ### Confident answer

      Rank the top 5 opensearch answers by confidence and provide the most likely answer if you are confident.

          {
            "answers": [
              { "commodity_code": "0101210000", "confidence": "Strong" },
              { "commodity_code": "0101290000", "confidence": "Good" },
              { "commodity_code": "0101300000", "confidence": "Possible" }
            ]
          }

      ### Follow-up questions

      Each question can have many possible answers. Try and ask as few questions as possible to narrow down the commodity code.

      **AVOID YES/NO QUESTIONS** unless they will help narrow down the commodity code by whole categories - a user can review each opensearch option themselves and answer yes/no so yes/no just makes the UX worse.

      Keep to one question per commodity code search.

          {
            "questions": [
              { "question": "What is the material of the clothing?", "options": ["Cotton", "Wool", "Synthetic"] }
            ]
          }

      Prefer questions and options that will help you narrow down the commodity code the most and avoid repeating the same question.

      Try and ask at least a few questions each time to narrow down the commodity code in an efficient way.

      ### Error

          {
            "error": "Contradictory answers given"
          }

      ## Rules

      - Always respond in JSON as per the three examples above and never try and code anything up.
      - Always structure questions so they have multiple meaningful options, not just yes/no.
      - Avoid hallucinating codes and only provide codes that you are certain of based on the information provided.

      ## Context sections

      -----------SEARCH_INPUT------------------
      %{search_input}
      -----------END SEARCH_INPUT--------------

      -----------EXPANDED_QUERY-----------------
      %{expanded_query}
      -----------END EXPANDED_QUERY-------------

      -----------ANSWERS_OPENSEARCH-------------
      %{answers_opensearch}
      -----------END ANSWERS_OPENSEARCH---------

      -----------QUESTIONS_AND_ANSWERS----------
      %{questions}
      -----------END QUESTIONS_AND_ANSWERS------
    MARKDOWN
  end

  def self_text_context_markdown
    <<~MARKDOWN.strip
      You are an expert in the UK Trade Tariff - a hierarchical classification system for goods.

      The tariff is a tree. Each node has a description. Some nodes are described as "Other" or contain "Other" with a qualifier - these are residual catch-all categories meaning "everything classified under the parent that is not specifically named by a sibling node."

      You will receive a JSON array of segments. Each segment contains:

      - **sid**: the goods_nomenclature_sid (unique identifier)
      - **code**: the goods_nomenclature_item_id (10-digit commodity code)
      - **description**: the node's original description (e.g. "Other", "Other, fresh or chilled", "Of pine (pinus spp.), other")
      - **parent**: the parent node's description (already contextualised if it was previously "Other")
      - **ancestor_chain**: the full path from the chapter root to this node's parent, joined with " > "
      - **siblings**: array of sibling node descriptions (the named categories at the same level)
      - **goods_nomenclature_class**: the type of node - "Chapter", "Heading", "Subheading", or "Commodity"
      - **declarable**: true if traders can declare goods against this code, false if it is a grouping node

      For each segment, produce a contextualised description that replaces the "Other" element while preserving any qualifier.

      ## Output format

      Return JSON with the following structure:

          {
            "descriptions": [
              {
                "sid": 12345,
                "contextualised_description": "Reeds, rushes, osier, raffia, cereal straw and lime bark for plaiting (excl. bamboos, rattans)",
                "excluded_siblings": ["Pure-bred breeding animals"]
              }
            ]
          }

      - **sid**: must match the input sid exactly
      - **contextualised_description**: your generated description
      - **excluded_siblings**: the sibling descriptions you excluded (should match the input siblings)

      ## Style rules

      - When the parent description contains examples (e.g. "for example, bamboos, rattans, reeds, rushes"), extract the examples that are NOT named as siblings and include them in your description. This tells traders what the "Other" category actually contains.
      - Example: parent "Vegetable materials of a kind used primarily for plaiting (for example, bamboos, rattans, reeds, rushes, osier, raffia, cleaned, bleached or dyed cereal straw, and lime bark)", siblings ["Bamboos", "Rattans"]
        -> "Reeds, rushes, osier, raffia, cereal straw and lime bark for plaiting (excl. bamboos, rattans)"
      - When the parent description has no examples, use the pattern: "<parent category> (excl. <named siblings>)"
      - Example: parent "Live horses", siblings ["Pure-bred breeding animals"]
        -> "Live horses (excl. pure-bred for breeding)"
      - Summarise long sibling lists rather than listing every one verbatim
      - Keep descriptions concise and terse - avoid verbose explanations
      - Do NOT include the commodity code in the description
      - Do NOT start with "Other" - give the positive category name first

      ## Qualified Other patterns

      Not all nodes are bare "Other". Some include a qualifier that must be preserved:

      - **"Other, qualifier"** (e.g. "Other, fresh or chilled"): Replace "Other" with parent context, keep the qualifier.
        - Example: description "Other, fresh or chilled", parent "Edible offal of bovine animals", siblings ["Tongues", "Livers"]
          -> "Edible offal of bovine animals, fresh or chilled (excl. tongues, livers)"
      - **"Other (qualifier)"** (e.g. "Other (including factory rejects)"): Replace "Other" with parent context, keep the parenthetical.
        - Example: description "Other (including factory rejects)", parent "Aluminium waste and scrap", siblings ["Turnings, shavings, chips"]
          -> "Aluminium waste and scrap (including factory rejects) (excl. turnings, shavings, chips)"
      - **"description, other"** (e.g. "Of pine (pinus spp.), other"): The ", other" is the residual marker. Keep the preceding description and add sibling exclusions.
        - Example: description "Of pine (pinus spp.), other", siblings ["Treated with paint, stains, creosote"]
          -> "Of pine (pinus spp.) (excl. treated with paint, stains, creosote)"
      - **Bare "Other"**: Handled by the standard rules above - replace entirely with parent context and sibling exclusions.

      ## Node type guidance

      - **Commodity** (declarable: true): This is the final code traders declare against. Be specific - traders need to know exactly what this covers.
      - **Subheading** (declarable: false): This is a grouping node with children beneath it. Traders navigate through it. Include enough detail to help them decide whether to look further.
      - **Heading** / **Chapter**: Broader groupings. Keep descriptions correspondingly broad.

      ## Critical rules

      - Read the ancestor_chain carefully to understand cumulative context. Each "Other" in the chain already excludes what its siblings named. Your description should reflect the FULL accumulated exclusions from the ancestor chain, not just immediate siblings.
      - "Other" means "NOT the named siblings within THIS parent". Do not positively identify it as one of the named siblings.
      - When the parent itself was "Other" (and has been contextualised), use that contextualised description to understand what this sub-branch covers.
      - When the parent description is very long, summarise it concisely.
      - Produce a description for EVERY segment in the input.
      - Do not invent classification detail - only use what the sibling and parent context provides.
    MARKDOWN
  end

  def expand_query_context_markdown
    <<~MARKDOWN.strip
      You are an expert in trade tariff classification and search queries.

      Your task is to rephrase and expand a given search query to improve its effectiveness when searching an OpenSearch index for trade commodities. The goal is to generate a query that is more likely to match relevant documents, especially considering that the original query might not use the exact terminology found in the tariff data.

      Provide only the rephrased and expanded search query as plain text, without any additional formatting or explanation.

      **Original search query:** %{search_query}

      ## Output format

      Return the expanded search query in the following JSON format:

          {
            "expanded_query": "string",
            "reason": "string"
          }

      The reason for the expansion should briefly explain why the changes were made to improve search effectiveness.

      ## Example

      For the search query "laptop":

          {
            "expanded_query": "Portable automatic data-processing machines",
            "reason": "The term 'laptop' is a common colloquial term, but the official tariff classification uses more formal terminology."
          }
    MARKDOWN
  end
  # rubocop:enable Metrics/MethodLength
end
# rubocop:enable Metrics/ModuleLength

namespace :admin_configurations do
  # Seed values should align with AdminConfiguration::DEFAULTS
  desc 'Seed initial admin configurations'
  task seed: :environment do
    model_options = OpenaiClient::MODEL_CONFIGS.keys.sort.map do |key|
      { 'key' => key, 'label' => AdminConfigurationSeeder.model_label(key) }
    end

    default_model = TradeTariffBackend.ai_model

    configs = [
      {
        name: 'expand_search_enabled',
        config_type: 'boolean',
        description: 'Expand search queries using AI to translate everyday language into tariff terminology before searching',
        value: 'true',
      },
      {
        name: 'expand_model',
        config_type: 'options',
        description: 'AI model used for search query expansion',
        value: { 'selected' => default_model, 'options' => model_options },
      },
      {
        name: 'expand_query_context',
        config_type: 'markdown',
        description: 'System prompt sent to the AI model when expanding search queries',
        value: AdminConfigurationSeeder.expand_query_context_markdown,
      },
      {
        name: 'interactive_search_enabled',
        config_type: 'boolean',
        description: 'Enable interactive Q&A to help traders narrow down commodity codes through clarifying questions',
        value: 'true',
      },
      {
        name: 'interactive_search_max_questions',
        config_type: 'integer',
        description: 'Maximum number of clarifying questions to ask before forcing a best-guess answer from the AI',
        value: '3',
      },
      {
        name: 'input_sanitiser_enabled',
        config_type: 'boolean',
        description: 'Sanitise and validate search queries before AI processing. Strips HTML, rejects non-printable characters, and enforces a maximum query length.',
        value: 'true',
      },
      {
        name: 'input_sanitiser_max_length',
        config_type: 'integer',
        description: 'Maximum allowed character length for search queries when input sanitiser is enabled',
        value: '500',
      },
      {
        name: 'label_context',
        config_type: 'markdown',
        description: 'System prompt sent to the AI model when labelling commodities',
        value: AdminConfigurationSeeder.label_context_markdown,
      },
      {
        name: 'label_model',
        config_type: 'options',
        description: 'AI model used for commodity labelling',
        value: { 'selected' => default_model, 'options' => model_options },
      },
      {
        name: 'label_page_size',
        config_type: 'integer',
        description: 'Number of commodities processed per batch during AI labelling',
        value: TradeTariffBackend.goods_nomenclature_label_page_size.to_s,
      },
      {
        name: 'opensearch_result_limit',
        config_type: 'integer',
        description: 'Maximum number of OpenSearch results fetched for AI processing during interactive search',
        value: '80',
      },
      {
        name: 'pos_noun_boost',
        config_type: 'integer',
        description: 'Boost factor for nouns in POS-tagged search queries. Higher values make noun matches dominate scoring.',
        value: '10',
      },
      {
        name: 'pos_qualifier_boost',
        config_type: 'integer',
        description: 'Boost factor for qualifiers (adjectives, past participles, gerunds) in POS-tagged search queries.',
        value: '3',
      },
      {
        name: 'pos_search_enabled',
        config_type: 'boolean',
        description: 'Use part-of-speech tagging to structure search queries. Nouns become required terms, modifiers become optional. When disabled, falls back to a single multi-match query.',
        value: 'true',
      },
      {
        name: 'self_text_batch_size',
        config_type: 'integer',
        description: 'Number of Other nodes processed per batch during AI self-text generation',
        value: '5',
      },
      {
        name: 'self_text_context',
        config_type: 'markdown',
        description: 'System prompt sent to the AI model when generating self-texts for Other nodes',
        value: AdminConfigurationSeeder.self_text_context_markdown,
      },
      {
        name: 'self_text_model',
        config_type: 'options',
        description: 'AI model used for generating self-texts for Other nodes',
        value: { 'selected' => default_model, 'options' => model_options },
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
        value: 'true',
      },
      {
        name: 'search_model',
        config_type: 'options',
        description: 'AI model used for interactive Q&A search',
        value: { 'selected' => default_model, 'options' => model_options },
      },
      {
        name: 'search_result_limit',
        config_type: 'integer',
        description: 'Maximum number of commodity code suggestions shown during interactive Q&A. The frontend uses this to decide how to display results (e.g. as a shortlist or expanded view).',
        value: '0',
      },
      {
        name: 'suggest_results_limit',
        config_type: 'integer',
        description: 'Maximum number of search suggestions returned by the internal suggestions endpoint',
        value: '10',
      },
      {
        name: 'suggest_chemical_cas',
        config_type: 'boolean',
        description: 'Enable CAS Registry Number suggestions and exact match redirects in internal search',
        value: 'false',
      },
      {
        name: 'suggest_chemical_cus',
        config_type: 'boolean',
        description: 'Enable CUS identifier suggestions and exact match redirects in internal search',
        value: 'false',
      },
      {
        name: 'suggest_chemical_names',
        config_type: 'boolean',
        description: 'Enable chemical substance name suggestions and exact match redirects in internal search',
        value: 'false',
      },
      {
        name: 'suggest_colloquial_terms',
        config_type: 'boolean',
        description: 'Enable AI-generated colloquial term suggestions and exact match redirects in internal search',
        value: 'false',
      },
      {
        name: 'suggest_known_brands',
        config_type: 'boolean',
        description: 'Enable AI-generated known brand suggestions and exact match redirects in internal search',
        value: 'false',
      },
      {
        name: 'suggest_synonyms',
        config_type: 'boolean',
        description: 'Enable AI-generated synonym suggestions and exact match redirects in internal search',
        value: 'false',
      },
    ]

    created = 0

    configs.each do |attrs|
      if AdminConfiguration.where(name: attrs[:name]).any?
        puts "  skip: #{attrs[:name]} (already exists)"
        next
      end

      AdminConfiguration.create(attrs.merge(area: 'classification'))
      puts "  created: #{attrs[:name]}"
      created += 1
    end

    if created.positive?
      AdminConfiguration.refresh!(concurrently: false)
      puts '  refreshed materialized view'
    end
  end

  desc 'Reset and reseed all admin configurations'
  task reseed: :environment do
    AdminConfiguration::Operation.truncate
    puts '  truncated admin configurations'

    AdminConfiguration.refresh!(concurrently: false)
    puts '  refreshed materialized view'

    Rake::Task['admin_configurations:seed'].invoke
  end
end
