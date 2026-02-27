module GenerateSelfText
  class MechanicalBuilder
    SEPARATOR = ' >> '.freeze
    OTHER_PATTERN = SegmentExtractor::OTHER_PATTERN

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
      stats = { processed: 0, skipped_other: 0, skipped_ai_non_other: 0, skipped: 0 }

      segments.each do |segment|
        node = segment[:node]

        if node[:is_other]
          stats[:skipped_other] += 1
          next
        end

        existing_record = existing[node[:sid]]
        if existing_record && existing_record[:generation_type] == 'ai_non_other'
          stats[:skipped_ai_non_other] += 1
          next
        end

        self_text = build_self_text(segment)
        input_context = build_input_context(segment)
        context_hash = Digest::SHA256.hexdigest(JSON.generate(input_context))

        if skip?(existing_record, context_hash)
          generated_texts[node[:sid]] = existing_record[:self_text]
          stats[:skipped] += 1
          next
        end

        upsert_record(node, self_text, input_context, context_hash)
        generated_texts[node[:sid]] = self_text
        stats[:processed] += 1
      end

      stats
    end

    private

    attr_reader :chapter, :generated_texts

    def preload_existing(segments)
      sids = segments.map { |s| s[:node][:sid] }
      GoodsNomenclatureSelfText.where(goods_nomenclature_sid: sids).each_with_object({}) do |record, hash|
        hash[record.goods_nomenclature_sid] = {
          context_hash: record.context_hash,
          self_text: record.self_text,
          stale: record.stale,
          manually_edited: record.manually_edited,
          generation_type: record.generation_type,
        }
        generated_texts[record.goods_nomenclature_sid] = record.self_text
      end
    end

    def skip?(existing, context_hash)
      existing &&
        existing[:context_hash] == context_hash &&
        !existing[:stale] &&
        !existing[:manually_edited]
    end

    def build_self_text(segment)
      ancestors = segment[:ancestor_chain]
      nearest_other_idx = ancestors.rindex { |a| OTHER_PATTERN.match?(a[:description].to_s) }

      parts = []

      if nearest_other_idx
        other_text = generated_texts[ancestors[nearest_other_idx][:sid]]

        if other_text
          parts << other_text

          ((nearest_other_idx + 1)...ancestors.size).each do |i|
            parts << ancestors[i][:description]
          end
        else
          # No AI text for the Other ancestor yet - fall back to including
          # non-Other ancestors and skipping the bare Other
          ancestors.each do |a|
            next if OTHER_PATTERN.match?(a[:description].to_s)

            parts << a[:description]
          end
        end
      else
        ancestors.each { |a| parts << a[:description] }
      end

      parts << segment[:node][:description]
      parts.join(SEPARATOR)
    end

    def build_input_context(segment)
      ancestors = segment[:ancestor_chain].map do |ancestor|
        entry = { 'sid' => ancestor[:sid], 'description' => ancestor[:description] }

        if OTHER_PATTERN.match?(ancestor[:description].to_s) && generated_texts[ancestor[:sid]]
          entry['self_text'] = generated_texts[ancestor[:sid]]
        end

        entry
      end

      { 'ancestors' => ancestors, 'description' => segment[:node][:description] }
    end

    def upsert_record(node, self_text, input_context, context_hash)
      now = Time.zone.now

      values = {
        goods_nomenclature_sid: node[:sid],
        goods_nomenclature_item_id: node[:code],
        self_text: self_text,
        generation_type: 'mechanical',
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
  end
end
