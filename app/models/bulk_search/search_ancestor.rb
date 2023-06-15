module BulkSearch
  class SearchAncestor
    include ContentAddressableId

    attr_accessor :short_code,
                  :goods_nomenclature_item_id,
                  :description,
                  :producline_suffix,
                  :goods_nomenclature_class,
                  :declarable,
                  :score,
                  :reason

    def id
      @id ||= "#{short_code}-#{producline_suffix}-#{presented_score}"
    end

    def presented_score
      (score.presence || 0).to_f.round(2)
    end

    def self.build(attributes)
      result = new

      result.short_code = attributes[:short_code]
      result.goods_nomenclature_item_id = attributes[:goods_nomenclature_item_id]
      result.description = attributes[:description]
      result.producline_suffix = attributes[:producline_suffix]
      result.goods_nomenclature_class = attributes[:goods_nomenclature_class]
      result.declarable = attributes[:declarable]
      result.score = attributes[:score]
      result.reason = attributes[:reason]

      result
    end
  end
end
