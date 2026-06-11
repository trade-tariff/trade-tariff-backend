module TariffKnowledge
  class CompressedNoteRefresh
    BATCH_SIZE = 500

    Result = Data.define(:goods_nomenclature_count, :expired_note_count)

    def self.call
      new.call
    end

    def call
      DeclarableNodeLoader.call
      SourceGraphLoader.call

      current_sids = current_goods_nomenclature_sids
      current_sids.each_slice(BATCH_SIZE) do |sids|
        CompressedNoteGenerator.call(goods_nomenclature_sids: sids)
      end

      Result.new(
        goods_nomenclature_count: current_sids.size,
        expired_note_count: expire_non_current_notes(current_sids),
      )
    end

  private

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
