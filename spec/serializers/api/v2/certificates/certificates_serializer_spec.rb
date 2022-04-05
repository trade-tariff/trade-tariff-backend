RSpec.describe Api::V2::Certificates::CertificatesSerializer do
  subject(:serializer) { described_class.new(serializable).serializable_hash.as_json }

  let(:serializable) do
    Hashie::TariffMash.new(
      Cache::CertificateSerializer.new(certificate).as_json,
    )
  end

  let(:certificate) do
    create(
      :certificate,
      :with_description,
      :with_certificate_type,
      :with_guidance,
    )
  end

  let(:expected_pattern) do
    {
      data: {
        id: String,
        type: 'certificates',
        attributes: {
          certificate_type_code: String,
          certificate_code: String,
          description: String,
          formatted_description: String,
          guidance_cds: String,
          guidance_chief: String,
        },
        relationships: {
          measures: Hash,
        },
      },
    }
  end

  describe '#serializable_hash' do
    it { is_expected.to match_json_expression(expected_pattern) }
  end
end
