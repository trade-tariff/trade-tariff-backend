RSpec.describe Api::V2::GreenLanes::CertificateSerializer do
  subject(:presented_serialized) do
    described_class.new(presented).serializable_hash.as_json
  end

  let(:serialized) do
    described_class.new(certificate).serializable_hash.as_json
  end
  let(:certificate) do
    create(:certificate, :with_description)
  end
  let :presented do
    Api::V2::GreenLanes::CertificatePresenter.wrap([certificate], 'measure_id', { certificate.id => '1' }).first
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
  let(:expected_presented_pattern) do
    {
      data: {
        id: be_a(String),
        type: 'certificate',
        attributes: {
          code: certificate.id,
          certificate_type_code: certificate.certificate_type_code,
          certificate_code: certificate.certificate_code,
          description: certificate.description,
          formatted_description: certificate.formatted_description,
          group_ids: '1',
        },
      },
    }
  end

  it {
    expect(serialized).to include_json(expected_pattern)
  }

  it {
    expect(presented_serialized).to include_json(expected_presented_pattern)
  }
end
