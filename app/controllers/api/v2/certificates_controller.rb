module Api
  module V2
    class CertificatesController < ApiController
      before_action :find_certificates, only: [:search]

      def search
        options = {}
        options[:include] = [:measures, 'measures.goods_nomenclature']
        render json: Api::V2::Certificates::CertificatesSerializer.new(@certificates, options.merge(serialization_meta)).serializable_hash
      end

      def index
        certificates = Certificate.actual
                                  .eager(:certificate_descriptions, :certificate_description_periods, :certificate_type_description)
                                  .order(Sequel.asc(%i[certificate_type_code certificate_code]))
                                  .all

        render json: Api::V2::Certificates::CertificateListSerializer.new(certificates).serializable_hash
      end

      private

      def find_certificates
        TimeMachine.now do
          @certificates = search_service.perform
        end
      end

      def search_service
        @search_service ||= CertificateSearchService.new(params, current_page, per_page)
      end

      def per_page
        5
      end

      def serialization_meta
        {
          meta: {
            pagination: {
              page: current_page,
              per_page: per_page,
              total_count: search_service.pagination_record_count,
            },
          },
        }
      end
    end
  end
end
