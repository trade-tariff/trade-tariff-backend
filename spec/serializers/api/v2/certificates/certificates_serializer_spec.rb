RSpec.describe Api::V2::Certificates::CertificatesSerializer do
  describe '#serializable_hash' do
    subject(:serializable_hash) { described_class.new(serializable).serializable_hash.as_json }

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

    before do
      allow(TradeTariffBackend).to receive(:service).and_return(service)
    end

    context 'when on uk service' do
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

      let(:service) { 'uk' }

      it { is_expected.to match_json_expression(expected_pattern) }
    end

    context 'when on xi service' do
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
              guidance_cds: nil,
              guidance_chief: nil,
            },
            relationships: {
              measures: Hash,
            },
          },
        }
      end

      let(:service) { 'xi' }

      it { is_expected.to match_json_expression(expected_pattern) }
    end
  end
end
