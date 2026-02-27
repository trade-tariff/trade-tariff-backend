module GenerateSelfText
  class OtherSelfTextBuilder
    OTHER_PATTERN = SegmentExtractor::OTHER_PATTERN
    SEPARATOR = ' >> '.freeze

    def self.call(chapter)
      new(chapter).call
    end

    def initialize(chapter)
      @chapter = chapter
      @generated_texts = {}
    end

    def call
      segments = SegmentExtractor.call(chapter, self_texts: generated_texts)
      existing = preload_existing(segments)

      other_segments = segments.select { |s| s[:node][:is_other] }
      stats = { processed: 0, failed: 0, skipped: 0 }

      segments_to_process = other_segments.reject do |segment|
        node = segment[:node]
        input_context = build_input_context(segment)
        context_hash = Digest::SHA256.hexdigest(JSON.generate(input_context))
        record = existing[node[:sid]]

        if skip?(record, context_hash)
          generated_texts[node[:sid]] = record[:self_text]
          stats[:skipped] += 1
          true
        else
          false
        end
      end

      segments_to_process.each_slice(batch_size) do |batch|
        process_batch(batch, stats)
      end

      stats
    end

    private

    attr_reader :chapter, :generated_texts

    def preload_existing(segments)
      sids = segments.map { |s| s[:node][:sid] }
      GoodsNomenclatureSelfText.where(goods_nomenclature_sid: sids).each_with_object({}) do |record, hash|
        generated_texts[record.goods_nomenclature_sid] = record.self_text
        hash[record.goods_nomenclature_sid] = {
          context_hash: record.context_hash,
          self_text: record.self_text,
          stale: record.stale,
          manually_edited: record.manually_edited,
        }
      end
    end

    def skip?(existing, context_hash)
      existing &&
        existing[:context_hash] == context_hash &&
        !existing[:stale] &&
        !existing[:manually_edited]
    end

    def process_batch(batch, stats)
      messages = build_messages(batch)
      response = SelfTextGenerator::Instrumentation.api_call(
        batch_size: batch.size,
        model: model,
        chapter_code: chapter.short_code,
      ) { TradeTariffBackend.ai_client.call(messages, model: model) }

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

        input_context = build_input_context(segment)
        upsert_record(node, desc['contextualised_description'], input_context)
        generated_texts[node[:sid]] = desc['contextualised_description']

        stats[:processed] += 1
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
        description: node[:description],
        parent: parent_text,
        ancestor_chain: ancestor_chain,
        siblings: siblings,
        goods_nomenclature_class: node[:goods_nomenclature_class],
        declarable: node[:declarable],
      }
    end

    def parse_response(response)
      return nil if response.blank?

      response = AiResponseSanitizer.call(response) if response.is_a?(String)
      response = ExtractBottomJson.call(response) unless response.is_a?(Hash) || response.is_a?(Array)

      return nil unless response.is_a?(Hash)

      # Sanitise again after JSON parsing - \u0000 escape sequences in the raw
      # JSON survive the initial string sanitisation but become real null bytes
      # after JSON.parse, which PostgreSQL rejects.
      response = AiResponseSanitizer.call(response)

      response['descriptions']
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
        'goods_nomenclature_class' => segment[:node][:goods_nomenclature_class],
        'declarable' => segment[:node][:declarable],
      }
    end

    def upsert_record(node, self_text, input_context)
      context_hash = Digest::SHA256.hexdigest(JSON.generate(input_context))
      now = Time.zone.now

      values = {
        goods_nomenclature_sid: node[:sid],
        goods_nomenclature_item_id: node[:code],
        self_text: self_text,
        generation_type: 'ai',
        input_context: Sequel.pg_jsonb_wrap(input_context),
        context_hash: context_hash,
        needs_review: false,
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
        prompt = AdminConfiguration.classification.by_name('other_self_text_context')&.value
        raise 'other_self_text_context admin configuration not found - run rake admin_configurations:seed' unless prompt

        prompt
      end
    end

    def model
      @model ||= AdminConfiguration.option_value('other_self_text_model')
    end

    def batch_size
      @batch_size ||= AdminConfiguration.integer_value('other_self_text_batch_size')
    end
  end
end
