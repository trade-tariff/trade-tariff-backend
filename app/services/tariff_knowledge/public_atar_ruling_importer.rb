require 'json'

module TariffKnowledge
  class PublicAtarRulingImporter
    Result = Data.define(:seen_count, :created_count, :updated_count, :failed_count, :refresh_goods_nomenclature_item_ids)
    UpsertResult = Data.define(:action, :refresh_goods_nomenclature_item_ids)

    DEFAULT_PRELOAD_PATH = Rails.root.join('db/tariff_knowledge/public_atar_rulings_preload.json')

    def self.call(...) = new.call(...)

    def self.import_file(...) = new.import_file(...)

    def initialize(source: nil)
      @source = source
    end

    def call(limit: nil, max_pages: 50, request_delay: PublicAtarRulingSource::DEFAULT_REQUEST_DELAY, max_retries: PublicAtarRulingSource::DEFAULT_MAX_RETRIES)
      sync_source = source || PublicAtarRulingSource.new(
        limit:,
        max_pages:,
        request_delay:,
        max_retries:,
      )
      seen_count = 0
      created_count = 0
      updated_count = 0
      failed_count = 0
      refresh_goods_nomenclature_item_ids = []
      remaining = limit

      (1..max_pages).each do |page|
        refs = sync_source.refs_for_page(page)
        break if refs.empty?

        refs = refs.first(remaining) if remaining
        seen_count += refs.size

        refs.each do |ref|
          upsert_result = upsert_ruling(sync_source.ruling_for_ref(ref))
          created_count += 1 if upsert_result.action == :created
          updated_count += 1 if upsert_result.action == :updated
          refresh_goods_nomenclature_item_ids.concat(upsert_result.refresh_goods_nomenclature_item_ids)
        rescue StandardError => e
          failed_count += 1
          Rails.logger.warn("Failed to import public ATAR #{ref}: #{e.class}: #{e.message}")
        end

        if remaining
          remaining -= refs.size
          break if remaining <= 0
        end
      end

      Result.new(seen_count:, created_count:, updated_count:, failed_count:, refresh_goods_nomenclature_item_ids: refresh_goods_nomenclature_item_ids.uniq)
    end

    def import_file(path: DEFAULT_PRELOAD_PATH)
      created_count = 0
      updated_count = 0
      failed_count = 0
      refresh_goods_nomenclature_item_ids = []
      rows = JSON.parse(File.read(path))

      rows.each do |attributes|
        ruling = ruling_from_hash(attributes)
        upsert_result = upsert_ruling(ruling, derived_fact_attributes: derived_fact_attributes_from_hash(attributes))
        created_count += 1 if upsert_result.action == :created
        updated_count += 1 if upsert_result.action == :updated
        refresh_goods_nomenclature_item_ids.concat(upsert_result.refresh_goods_nomenclature_item_ids)
      rescue StandardError => e
        failed_count += 1
        Rails.logger.warn("Failed to import public ATAR #{attributes['ref'] || 'unknown'}: #{e.class}: #{e.message}")
      end

      Result.new(seen_count: rows.size, created_count:, updated_count:, failed_count:, refresh_goods_nomenclature_item_ids: refresh_goods_nomenclature_item_ids.uniq)
    end

  private

    attr_reader :source

    def upsert_ruling(ruling, derived_fact_attributes: nil)
      existing = PublicAtarRuling.by_ref(ruling.ref).first
      now = Time.zone.now
      action = existing ? :updated : :created
      row = row_for(ruling, existing:, now:, derived_fact_attributes:)
      refresh_goods_nomenclature_item_ids = search_refresh_item_ids(existing, row)

      PublicAtarRuling.dataset
                       .insert_conflict(target: :ref, update: update_values(update_derived_facts: derived_fact_attributes.present?))
                       .insert(row)

      UpsertResult.new(action:, refresh_goods_nomenclature_item_ids:)
    end

    def search_refresh_item_ids(existing, row)
      return [row[:goods_nomenclature_item_id]] unless existing

      [existing.goods_nomenclature_item_id, row[:goods_nomenclature_item_id]].compact.uniq
    end

    def row_for(ruling, existing:, now:, derived_fact_attributes:)
      row = {
        ref: ruling.ref,
        commodity_code: ruling.commodity_code,
        goods_nomenclature_item_id: ruling.goods_nomenclature_item_id,
        description: ruling.description,
        keywords: Sequel.pg_array(Array(ruling.keywords), :text),
        justification: ruling.justification,
        validity_start_date: parse_date(ruling.validity_start_date),
        validity_end_date: parse_date(ruling.validity_end_date),
        source_url: ruling.source_url,
        raw_fields: Sequel.pg_jsonb(ruling.raw_fields || {}),
        first_seen_at: existing&.first_seen_at || now,
        last_seen_at: now,
        fetched_at: now,
        created_at: now,
        updated_at: now,
      }
      row.merge!(derived_fact_attributes) if derived_fact_attributes.present?
      row
    end

    def update_values(update_derived_facts:)
      values = {
        commodity_code: Sequel[:excluded][:commodity_code],
        goods_nomenclature_item_id: Sequel[:excluded][:goods_nomenclature_item_id],
        description: Sequel[:excluded][:description],
        keywords: Sequel[:excluded][:keywords],
        justification: Sequel[:excluded][:justification],
        validity_start_date: Sequel[:excluded][:validity_start_date],
        validity_end_date: Sequel[:excluded][:validity_end_date],
        source_url: Sequel[:excluded][:source_url],
        raw_fields: Sequel[:excluded][:raw_fields],
        last_seen_at: Sequel[:excluded][:last_seen_at],
        fetched_at: Sequel[:excluded][:fetched_at],
        updated_at: Sequel[:excluded][:updated_at],
      }

      values[:derived_facts] = Sequel[:excluded][:derived_facts] if update_derived_facts

      values
    end

    def ruling_from_hash(attributes)
      PublicAtarRulingSource::Ruling.new(
        ref: attributes.fetch('ref'),
        commodity_code: attributes.fetch('commodity_code'),
        goods_nomenclature_item_id: attributes.fetch('goods_nomenclature_item_id'),
        description: attributes.fetch('description'),
        keywords: attributes.fetch('keywords'),
        justification: attributes.fetch('justification'),
        validity_start_date: attributes.fetch('validity_start_date'),
        validity_end_date: attributes.fetch('validity_end_date'),
        source_url: attributes.fetch('source_url'),
        raw_fields: attributes.fetch('raw_fields'),
      )
    end

    def derived_fact_attributes_from_hash(attributes)
      return unless attributes.key?('derived_facts')

      derived_facts = attributes.fetch('derived_facts')
      return if derived_facts.nil?

      {
        derived_facts: Sequel.pg_array(Array(derived_facts).compact_blank, :text),
      }
    end

    def parse_date(value)
      return value if value.is_a?(Date) || value.nil?

      Date.parse(value.to_s)
    end
  end
end
