module Api
  module V2
    module AdditionalCodeSearch
      class AdditionalCodePresenter < WrapDelegator
        def self.wrap(additional_codes, grouped_goods_nomenclatures)
          additional_codes.map do |additional_code|
            goods_nomenclatures = grouped_goods_nomenclatures[additional_code.additional_code_sid]

            new(additional_code, goods_nomenclatures)
          end
        end

        attr_reader :goods_nomenclatures

        def initialize(additional_code, goods_nomenclatures)
          super(additional_code)

          @additional_code = additional_code
          @goods_nomenclatures = goods_nomenclatures
        end

        def goods_nomenclature_ids
          goods_nomenclatures.map(&:goods_nomenclature_sid)
        end
      end
    end
  end
end
