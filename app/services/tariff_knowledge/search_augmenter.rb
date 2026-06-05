module TariffKnowledge
  class SearchAugmenter
    HEADER = 'Tariff note context'.freeze

    def self.call(results)
      new(results).call
    end

    def initialize(results)
      @results = results
    end

    def call
      return results if results.empty?

      contexts = DeclarableContext
        .by_sids(results.filter_map(&:goods_nomenclature_sid))
        .where(expired: false)
        .all
        .index_by(&:goods_nomenclature_sid)

      results.map do |result|
        context = contexts[result.goods_nomenclature_sid]
        context ? with_context(result, context.content) : result
      end
    end

  private

    attr_reader :results

    def with_context(result, content)
      full_description = [result.full_description.presence || result.description, "#{HEADER}:\n#{content}"].compact.join("\n\n")

      GoodsNomenclatureResult.new(
        id: result.id,
        goods_nomenclature_item_id: result.goods_nomenclature_item_id,
        goods_nomenclature_sid: result.goods_nomenclature_sid,
        producline_suffix: result.producline_suffix,
        goods_nomenclature_class: result.goods_nomenclature_class,
        description: result.description,
        formatted_description: result.formatted_description,
        self_text: result.self_text,
        classification_description: result.classification_description,
        full_description: full_description,
        heading_description: result.heading_description,
        declarable: result.declarable,
        score: result.score,
        confidence: result.confidence,
      )
    end
  end
end
