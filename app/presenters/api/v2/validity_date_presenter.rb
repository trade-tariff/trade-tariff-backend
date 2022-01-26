module Api
  module V2
    class ValidityDatePresenter < SimpleDelegator
      def validity_date_id
        [
          goods_nomenclature_item_id,
          validity_start_date&.to_i,
          validity_end_date&.to_i,
        ].map(&:to_s).join('-')
      end
    end
  end
end
