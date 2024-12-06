module Api
  module V2
    class ChemicalSubstancesController < ApplicationController
      def index
        render json: serialized_chemicals
      end

      private

      def serialized_chemicals
        Api::V2::FullChemicalSerializer.new(full_chemicals).serializable_hash
      end

      def full_chemicals
        @full_chemicals ||= FullChemical.with_filter(full_chemical_params)
      end

      def full_chemical_params
        params.fetch(:filter, {}).permit(
          :cas_rn,
          :cus,
          :goods_nomenclature_sid,
          :goods_nomenclature_item_id,
        ).to_h
      end
    end
  end
end
