module TariffKnowledge
  class CompressedNoteRefresh
    BATCH_SIZE = 500
    FINGERPRINT_CACHE_KEY = 'tariff_knowledge:compressed_note_refresh:fingerprint'.freeze

    Result = Data.define(:goods_nomenclature_count, :expired_note_count, :skipped)

    def self.call
      new.call
    end

    def call
      current_version = current_source_version
      current_sids    = current_goods_nomenclature_sids

      return Result.new(goods_nomenclature_count: 0, expired_note_count: 0, skipped: true) \
        if fingerprint_unchanged?(current_version, current_sids)

      DeclarableNodeLoader.call
      SourceGraphLoader.call

      current_sids.each_slice(BATCH_SIZE) do |sids|
        CompressedNoteGenerator.call(goods_nomenclature_sids: sids)
      end

      expired_note_count = expire_non_current_notes(current_sids)
      store_fingerprint(current_version, current_sids)

      Result.new(
        goods_nomenclature_count: current_sids.size,
        expired_note_count: expired_note_count,
        skipped: false,
      )
    end

  private

    def current_source_version
      TimeMachine.now { CustomsTariffUpdate.latest.get(:version) }
    end

    def fingerprint_unchanged?(version, sids)
      stored = Rails.cache.read(FINGERPRINT_CACHE_KEY)
      return false unless stored

      stored[:version] == version && stored[:sids_digest] == sids_digest(sids)
    end

    def store_fingerprint(version, sids)
      Rails.cache.write(
        FINGERPRINT_CACHE_KEY,
        { version:, sids_digest: sids_digest(sids) },
        expires_in: 8.days,
      )
    end

    def sids_digest(sids)
      Digest::SHA256.hexdigest(sids.join(','))
    end

    def current_goods_nomenclature_sids
      if TimeMachine.date_is_set?
        current_goods_nomenclature_sids_at_time_machine_date
      else
        TimeMachine.now { current_goods_nomenclature_sids_at_time_machine_date }
      end
    end

    def current_goods_nomenclature_sids_at_time_machine_date
      GoodsNomenclature
        .actual
        .with_leaf_column
        .declarable
        .non_hidden
        .unordered
        .select_map(Sequel[:goods_nomenclatures][:goods_nomenclature_sid])
        .compact
        .uniq
        .sort
    end

    def expire_non_current_notes(current_sids)
      dataset = CompressedNote.where(expired: false)
      dataset = dataset.exclude(goods_nomenclature_sid: current_sids) if current_sids.any?

      dataset.update(expired: true)
    end
  end
end
