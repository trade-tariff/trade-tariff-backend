module GenerateSelfText
  class AiBuilder
    OTHER_PATTERN = SegmentExtractor::OTHER_PATTERN
    SEPARATOR = ' > '.freeze

    def self.call(chapter)
      new(chapter).call
    end

    def initialize(chapter)
      @chapter = chapter
      @generated_texts = {}
    end

    def call
      segments = SegmentExtractor.call(chapter, self_texts: generated_texts)
      preload_existing_self_texts(segments)

      other_segments = segments.select { |s| s[:node][:is_other] }
      stats = { processed: 0, failed: 0, needs_review: 0 }

      other_segments.each_slice(batch_size) do |batch|
        process_batch(batch, stats)
      end

      stats
    end

    private

    attr_reader :chapter, :generated_texts

    def preload_existing_self_texts(segments)
      sids = segments.map { |s| s[:node][:sid] }
      GoodsNomenclatureSelfText.where(goods_nomenclature_sid: sids).each do |record|
        generated_texts[record.goods_nomenclature_sid] = record.self_text
      end
    end

    def process_batch(batch, stats)
      messages = build_messages(batch)
      response = TradeTariffBackend.ai_client.call(messages, model: model)

      descriptions = parse_response(response)

      unless descriptions.is_a?(Array)
        stats[:failed] += batch.size
        return
      end

      descriptions_by_sid = descriptions.each_with_object({}) do |desc, hash|
        hash[desc['sid']] = desc if desc.is_a?(Hash) && desc['sid']
      end

      batch.each do |segment|
        node = segment[:node]
        desc = descriptions_by_sid[node[:sid]]

        unless desc&.dig('contextualised_description')
          stats[:failed] += 1
          next
        end

        needs_review = validate_siblings(desc, segment)
        input_context = build_input_context(segment)
        upsert_record(node, desc['contextualised_description'], input_context, needs_review)
        generated_texts[node[:sid]] = desc['contextualised_description']

        stats[:processed] += 1
        stats[:needs_review] += 1 if needs_review
      end
    end

    def build_messages(batch)
      segments_json = batch.map { |segment| segment_to_json(segment) }

      [
        { role: 'system', content: system_prompt },
        { role: 'user', content: JSON.generate(segments_json) },
      ]
    end

    def segment_to_json(segment)
      node = segment[:node]
      ancestors = segment[:ancestor_chain]

      parent_text = if ancestors.any?
                      last_ancestor = ancestors.last
                      generated_texts[last_ancestor[:sid]] || last_ancestor[:description]
                    end

      ancestor_chain = ancestors.map { |a|
        generated_texts[a[:sid]] || a[:description]
      }.join(SEPARATOR)

      siblings = segment[:siblings].map { |s| s[:description] }

      {
        sid: node[:sid],
        code: node[:code],
        parent: parent_text,
        ancestor_chain: ancestor_chain,
        siblings: siblings,
      }
    end

    def parse_response(response)
      return nil if response.blank?

      response = AiResponseSanitizer.call(response) if response.is_a?(String)
      response = ExtractBottomJson.call(response) unless response.is_a?(Hash) || response.is_a?(Array)

      return nil unless response.is_a?(Hash)

      response['descriptions']
    end

    def validate_siblings(desc, segment)
      excluded = desc['excluded_siblings']
      return true unless excluded.is_a?(Array)

      actual_siblings = segment[:siblings]
      excluded.size != actual_siblings.size
    end

    def build_input_context(segment)
      ancestors = segment[:ancestor_chain].map do |ancestor|
        entry = { 'sid' => ancestor[:sid], 'description' => ancestor[:description] }

        if generated_texts[ancestor[:sid]]
          entry['self_text'] = generated_texts[ancestor[:sid]]
        end

        entry
      end

      siblings = segment[:siblings].map { |s| s[:description] }

      {
        'ancestors' => ancestors,
        'description' => segment[:node][:description],
        'siblings' => siblings,
      }
    end

    def upsert_record(node, self_text, input_context, needs_review)
      context_hash = Digest::SHA256.hexdigest(JSON.generate(input_context))
      now = Time.zone.now

      values = {
        goods_nomenclature_sid: node[:sid],
        goods_nomenclature_item_id: node[:code],
        self_text: self_text,
        generation_type: 'ai',
        input_context: Sequel.pg_jsonb_wrap(input_context),
        context_hash: context_hash,
        needs_review: needs_review,
        manually_edited: false,
        stale: false,
        generated_at: now,
        created_at: now,
        updated_at: now,
      }

      GoodsNomenclatureSelfText.dataset.insert_conflict(
        constraint: :goods_nomenclature_self_texts_pkey,
        update: {
          self_text: Sequel[:excluded][:self_text],
          generation_type: Sequel[:excluded][:generation_type],
          input_context: Sequel[:excluded][:input_context],
          context_hash: Sequel[:excluded][:context_hash],
          needs_review: Sequel[:excluded][:needs_review],
          stale: false,
          generated_at: Sequel[:excluded][:generated_at],
          updated_at: Sequel[:excluded][:updated_at],
        },
        update_where: Sequel.&(
          { Sequel[:goods_nomenclature_self_texts][:manually_edited] => false },
          Sequel.~(Sequel[:goods_nomenclature_self_texts][:context_hash] => context_hash),
        ),
      ).insert(values)
    end

    def system_prompt
      @system_prompt ||= begin
        prompt = AdminConfiguration.classification.by_name('self_text_context')&.value
        raise 'self_text_context admin configuration not found - run rake admin_configurations:seed' unless prompt

        prompt
      end
    end

    def model
      @model ||= AdminConfiguration.option_value('self_text_model')
    end

    def batch_size
      @batch_size ||= AdminConfiguration.integer_value('self_text_batch_size')
    end
  end
end
