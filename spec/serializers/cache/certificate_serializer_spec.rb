RSpec.describe Cache::CertificateSerializer do
  subject(:serialized) { described_class.new(certificate, []).as_json }

  let(:certificate) do
    create(
      :certificate,
      :with_guidance,
      :with_description,
    )
  end

  let(:measure_with_goods_nomenclature) do
    create(
      :measure,
      :with_base_regulation,
      :with_measure_conditions,
      certificate_code: certificate.certificate_code,
      certificate_type_code: certificate.certificate_type_code,
      goods_nomenclature: create(:heading, :with_description),
    )
  end

  let(:pattern) do
    {
      id: String,
      certificate_type_code: String,
      certificate_code: String,
      description: String,
      formatted_description: String,
      validity_start_date: Time,
      validity_end_date: nil,
      measure_ids: [measure_with_goods_nomenclature.measure_sid],
      measures: Array,
      guidance_cds: String,
      guidance_chief: String,
    }
  end

  before do
    measure_with_goods_nomenclature
    # Missing goods nomenclature
    create(
      :measure,
      :with_base_regulation,
      :with_measure_conditions,
      certificate_code: certificate.certificate_code,
      certificate_type_code: certificate.certificate_type_code,
      goods_nomenclature: nil,
    )

    # No approved regulation
    create(
      :measure,
      :with_unapproved_base_regulation,
      :with_measure_conditions,
      certificate_code: certificate.certificate_code,
      certificate_type_code: certificate.certificate_type_code,
      goods_nomenclature: create(:heading, :with_description),
    )
  end

  it { is_expected.to match_json_expression(pattern) }
end
