module TariffKnowledge
  class DeclarableLoader
    def self.call
      new.call
    end

    def call
      TimeMachine.now do
        GoodsNomenclature.actual
                         .with_leaf_column
                         .declarable
                         .paged_each(rows_per_fetch: 500)
                         .each_slice(500) do |declarables|
          NodeRepository.bulk_upsert_goods_nomenclatures(declarables.map(&:sti_cast))
        end
      end
    end
  end
end
