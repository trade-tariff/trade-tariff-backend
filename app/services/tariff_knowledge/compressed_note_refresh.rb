module TariffKnowledge
  class CompressedNoteRefresh
    Result = Data.define(:goods_nomenclature_count, :expired_note_count)

    def self.call
      new.call
    end

    def call
      DeclarableNodeLoader.call
      SourceGraphLoader.call

      current_sids = current_goods_nomenclature_sids
      CompressedNoteGenerator.call(goods_nomenclature_sids: current_sids)

      Result.new(
        goods_nomenclature_count: current_sids.size,
        expired_note_count: expire_non_current_notes(current_sids),
      )
    end

  private

    def current_goods_nomenclature_sids
      Node.goods_nomenclatures
          .select_map(:goods_nomenclature_sid)
          .compact
          .uniq
          .sort
    end

    def expire_non_current_notes(current_sids)
      dataset = CompressedNote.exclude(goods_nomenclature_sid: current_sids)
                              .where(expired: false)
      count = dataset.count
      dataset.update(expired: true) if count.positive?
      count
    end
  end
end
