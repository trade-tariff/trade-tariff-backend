module Cache
  class CertificateSerializer
    include ::Cache::SearchCacheMethods

    attr_reader :certificate, :as_of

    def initialize(certificate)
      @certificate = certificate
      @as_of = Time.zone.today.midnight
    end

    def as_json
      measures = certificate.measures.select do |measure|
        has_valid_dates(measure)
      end
      {
        id: certificate.id,
        certificate_type_code: certificate.certificate_type_code,
        certificate_code: certificate.certificate_code,
        description: certificate.description,
        formatted_description: certificate.formatted_description,
        validity_start_date: certificate.validity_start_date,
        validity_end_date: certificate.validity_end_date,
        measure_ids: measures.map(&:measure_sid),
        measures: measures.map do |measure|
          {
            id: measure.measure_sid,
            measure_sid: measure.measure_sid,
            validity_start_date: measure.validity_start_date,
            validity_end_date: measure.validity_end_date,
            goods_nomenclature_item_id: measure.goods_nomenclature_item_id,
            goods_nomenclature_sid: measure.goods_nomenclature_sid,
            goods_nomenclature: goods_nomenclature_attributes(measure.goods_nomenclature)
          }
        end
      }
    end
  end
end
