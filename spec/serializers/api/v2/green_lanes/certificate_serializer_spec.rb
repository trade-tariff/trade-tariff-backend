RSpec.describe Api::V2::GreenLanes::CertificateSerializer do
  subject(:serialized) do
    described_class.new(certificate).serializable_hash.as_json
  end

  let(:certificate) do
    create(:certificate, :with_description)
  end

  let(:expected_pattern) do
    {
      data: {
        id: certificate.id,
        type: 'certificate',
        attributes: {
          code: certificate.id,
          certificate_type_code: certificate.certificate_type_code,
          certificate_code: certificate.certificate_code,
          description: certificate.description,
          formatted_description: certificate.formatted_description,
        },
      },
    }
  end

  it {
    expect(serialized).to include_json(expected_pattern)
  }
end
