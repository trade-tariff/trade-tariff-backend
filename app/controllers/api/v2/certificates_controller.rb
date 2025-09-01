module Api
  module V2
    class CertificatesController < ApiController
      def search
        if search_validator.valid?
          render json: serialized_certificates
        else
          render json: serialized_errors, status: :unprocessable_content
        end
      end

      def index
        render json: serialized_list_of_certificates
      end

      private

      def serialized_list_of_certificates
        Api::V2::Certificates::CertificateListSerializer.new(
          certificates,
        ).serializable_hash
      end

      def serialized_certificates
        Api::V2::Certificates::CertificatesSerializer.new(
          finder_service.call,
          include: %i[goods_nomenclatures],
        ).serializable_hash
      end

      def certificates
        Certificate
          .actual
          .eager(
            :certificate_descriptions,
            :certificate_description_periods,
            :certificate_type_description,
            :appendix_5a,
          )
          .order(Sequel.asc(%i[certificate_type_code certificate_code]))
          .all
      end

      def finder_service
        @finder_service ||= CertificateFinderService.new(
          type,
          code,
          description,
        )
      end

      def type
        certificate_search_params[:type]
      end

      def code
        certificate_search_params[:code]
      end

      def description
        certificate_search_params[:description]
      end

      def certificate_search_params
        params.permit(:type, :code, :description)
      end

      def search_validator
        @search_validator ||= SearchValidator.new(certificate_search_params)
      end

      def serialized_errors
        Api::Search::ErrorSerializationService.new(search_validator).call
      end
    end
  end
end
