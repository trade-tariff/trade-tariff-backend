module TariffKnowledge
  class Pipeline
    Result = Data.define(:source_count, :rule_count, :goods_nomenclature_count, :context_count, :coverage)

    def self.call(sources: SourceLoader.call)
      new(sources).call
    end

    def initialize(sources)
      @sources = sources
    end

    def call
      StaleGraphPruner.call(expected_sources: sources)
      DeclarableLoader.call
      NoteIngestion.call(sources:)
      DeclarableContextCompressor.call(goods_nomenclature_sids:)

      Result.new(
        source_count: sources.size,
        rule_count: Node.rules.count,
        goods_nomenclature_count: Node.goods_nomenclatures.count,
        context_count: DeclarableContext.count,
        coverage: CoverageAnalyzer.call(expected_sources: sources),
      )
    end

  private

    attr_reader :sources

    def goods_nomenclature_sids
      Node.goods_nomenclatures.select_map(:goods_nomenclature_sid).compact
    end
  end
end
