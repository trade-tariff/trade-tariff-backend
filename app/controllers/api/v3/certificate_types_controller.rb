module Api
  module V3
    class CertificateTypesController < BaseController
      def index
        certificate_types = CertificateType.actual
          .eager(:certificate_type_description)
          .order(Sequel.asc(:certificate_type_code))
          .all
        render json: Api::V3::CertificateSerializer.type_collection(certificate_types)
      end
    end
  end
end
