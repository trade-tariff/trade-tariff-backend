module Api
  module V3
    class CertificateSerializer
      def initialize(certificate)
        @certificate = certificate
      end

      def call
        {
          certificate_type_code: @certificate.certificate_type_code,
          certificate_code: @certificate.certificate_code,
          description: @certificate.description,
          validity_start_date: @certificate.validity_start_date,
          validity_end_date: @certificate.validity_end_date,
        }
      end

      def self.collection(certificates)
        list = certificates.map { |c| new(c).call }
        { data: list, meta: { total: list.size } }
      end

      def self.type_collection(certificate_types)
        list = certificate_types.map do |ct|
          {
            certificate_type_code: ct.certificate_type_code,
            description: ct.description,
            validity_start_date: ct.validity_start_date,
            validity_end_date: ct.validity_end_date,
          }
        end
        { data: list, meta: { total: list.size } }
      end
    end
  end
end
