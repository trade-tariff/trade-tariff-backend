RSpec.describe Api::V2::Certificates::CertificateListSerializer do
  subject(:serializer) { described_class.new(certificates).serializable_hash.as_json }

  let(:certificate) { create :certificate }
  let(:certificates) { [certificate] }

  let(:certificate_type) do
    create :certificate_type, :with_description,
           certificate_type_code: certificate.certificate_type_code
  end

  let(:certificate_description) do
    create :certificate_description, :with_period,
           certificate_type_code: certificate.certificate_type_code,
           certificate_code: certificate.certificate_code
  end

  let(:expected_pattern) do
    {
      data: [{
        id: String,
        type: 'certificate_type',
        attributes: {
          certificate_type_code: certificate.certificate_type_code,
          certificate_code: certificate.certificate_code,
          description: certificate.certificate_description.description,
          formatted_description: certificate.certificate_description.formatted_description,
          certificate_type_description: certificate.certificate_type_description.description,
          validity_start_date: certificate.certificate_description_period.validity_start_date,
        },
      }],
    }
  end

  before do
    certificate
    certificate_description
    certificate_type
  end

  describe '#serializable_hash' do
    it { is_expected.to match_json_expression(expected_pattern) }
  end
end
