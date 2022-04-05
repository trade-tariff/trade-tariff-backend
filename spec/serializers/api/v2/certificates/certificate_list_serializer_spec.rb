RSpec.describe Api::V2::Certificates::CertificateListSerializer do
  describe '#serializable_hash' do
    subject(:serializable_hash) { described_class.new([certificate]).serializable_hash.as_json }

    let(:certificate) { create(:certificate, :with_description, :with_certificate_type, :with_guidance) }

    before do
      allow(TradeTariffBackend).to receive(:service).and_return(service)
    end

    context 'when on uk service' do
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
                guidance_chief: String,
              },
            },
          ],
        }
      end

      let(:service) { 'uk' }

      it { is_expected.to match_json_expression(expected_pattern) }
    end

    context 'when on xi service' do
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
                guidance_cds: nil,
                guidance_chief: nil,
              },
            },
          ],
        }
      end

      let(:service) { 'xi' }

      it { is_expected.to match_json_expression(expected_pattern) }
    end
  end
end
