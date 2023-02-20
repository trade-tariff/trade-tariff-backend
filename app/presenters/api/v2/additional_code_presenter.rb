module Api
  module V2
    class AdditionalCodePresenter < SimpleDelegator
      attr_reader :goods_nomenclatures

      def initialize(additional_code, goods_nomenclatures)
        @goods_nomenclatures = goods_nomenclatures

        super(additional_code)
      end

      def self.wrap(additional_codes, candidate_goods_nomenclatures)
        Array.wrap(additional_codes).map do |additional_code|
          goods_nomenclatures = candidate_goods_nomenclatures.fetch(additional_code.additional_code_sid, [])
          new(additional_code, goods_nomenclatures)
        end
      end

      def goods_nomenclature_ids
        @goods_nomenclatures.map(&:goods_nomenclature_sid)
      end
    end
  end
end
