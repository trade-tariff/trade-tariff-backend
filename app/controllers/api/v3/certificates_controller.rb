module Api
  module V3
    class CertificatesController < BaseController
      def index
        certificates = Certificate.actual
          .eager(:certificate_descriptions, :certificate_type_description)
          .order(Sequel.asc(%i[certificate_type_code certificate_code]))
          .all
        render json: Api::V3::CertificateSerializer.collection(certificates)
      end
    end
  end
end
