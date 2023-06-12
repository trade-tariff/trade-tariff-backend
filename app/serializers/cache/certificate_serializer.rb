module Cache
  class CertificateSerializer
    include ::Cache::SearchCacheMethods

    def initialize(certificate)
      @certificate = certificate
    end

    def as_json
      {
        id: certificate.id,
        certificate_type_code: certificate.certificate_type_code,
        certificate_code: certificate.certificate_code,
        description: certificate.description,
        formatted_description: certificate.formatted_description,
        validity_start_date: certificate.validity_start_date,
        validity_end_date: certificate.validity_end_date,
        guidance_cds: certificate.guidance_cds,
        guidance_chief: certificate.guidance_chief,
        measure_ids: measures.map(&:measure_sid),
        measures: measures.map do |measure|
          {
            id: measure.measure_sid,
            measure_sid: measure.measure_sid,
            validity_start_date: measure.validity_start_date,
            validity_end_date: measure.validity_end_date,
            goods_nomenclature_item_id: measure.goods_nomenclature_item_id,
            goods_nomenclature_sid: measure.goods_nomenclature_sid,
            goods_nomenclature_id: measure.goods_nomenclature_sid,
            goods_nomenclature: goods_nomenclature_attributes(measure.goods_nomenclature),
            geographical_area_id: measure.geographical_area_id,
            geographical_area: geographical_area_attributes(measure.geographical_area),
          }
        end,
      }
    end

    private

    attr_reader :certificate

    def measures
      @measures ||= certificate
        .measures_dataset
        .with_generating_regulation
        .eager(:goods_nomenclature)
        .exclude(goods_nomenclature_item_id: nil)
        .all
        .select do |measure|
          measure.goods_nomenclature.present? &&
            HiddenGoodsNomenclature.codes.exclude?(measure.goods_nomenclature_item_id)
        end
    end
  end
end
