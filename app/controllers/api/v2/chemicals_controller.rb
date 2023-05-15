module Api
  module V2
    class ChemicalsController < ApiController
      def index
        @chemicals = Chemical.eager(:chemical_names).all

        render json: Api::V2::Chemicals::ChemicalSimpleListSerializer.new(@chemicals).serializable_hash
      end

      def show
        @chemical = Chemical.first(cas: params[:id])
        # ^ `params[:id]` is a CAS Number, e.g., '22199-08-2'

        if @chemical.present?
          render json: Api::V2::Chemicals::ChemicalSerializer.new(@chemical, object_serializer_options.merge(is_collection: false)).serializable_hash
        else
          raise Sequel::RecordNotFound
        end
      end

      def search
        @chemicals = search_service.perform
        if @chemicals.present?
          render json: Api::V2::Chemicals::ChemicalListSerializer.new(@chemicals, object_serializer_options.merge(serialization_meta)).serializable_hash
        else
          raise Sequel::RecordNotFound
        end
      end

      private

      def search_service
        @search_service ||= ChemicalSearchService.new(params, current_page, per_page)
      end

      def object_serializer_options
        options = {}
        options[:include] = %i[goods_nomenclatures chemical_names]
        options
      end
    end
  end
end
