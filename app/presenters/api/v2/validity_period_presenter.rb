module Api
  module V2
    class ValidityPeriodPresenter < SimpleDelegator
      BREXIT_STARTING_DATE = Date.new(2021, 1, 1)

      include ContentAddressableId

      def self.wrap(goods_nomenclatures)
        Array.wrap(goods_nomenclatures).map { |goods_nomenclature| new(goods_nomenclature) }
      end

      content_addressable_fields :to_param,
                                 :validity_start_date,
                                 :validity_end_date

      def deriving_goods_nomenclatures
        candidate_goods_nomenclatures = deriving_goods_nomenclature_origins.map(&:goods_nomenclature)
        candidate_goods_nomenclatures.reject { |gn| gn.validity_start_date < BREXIT_STARTING_DATE }
      end
    end
  end
end
