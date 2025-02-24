RSpec.describe Api::V2::Certificates::CertificateListSerializer do
  subject(:serializer) { described_class.new([certificate]).serializable_hash.as_json }

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
      data: [
        {
          id: String,
          type: 'certificate',
          attributes: {
            certificate_type_code: String,
            certificate_code: String,
            description: String,
            formatted_description: String,
            certificate_type_description: String,
            validity_start_date: String,
            guidance_cds: String,
          },
        },
      ],
    }
  end

  describe '#serializable_hash' do
    it { is_expected.to match_json_expression(expected_pattern) }
  end
end
