RSpec.describe Api::V2::Certificates::CertificatesSerializer do
  describe '#serializable_hash' do
    subject(:serializer) { described_class.new(serializable).serializable_hash }

    let(:serializable) do
      Api::V2::CertificateSearch::CertificatePresenter.new(
        certificate,
        create_list(:heading, 1, :with_description),
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
          type: eq(:certificates),
          attributes: {
            certificate_type_code: String,
            certificate_code: String,
            description: String,
            formatted_description: String,
            guidance_cds: String,
            # guidance_chief: String,
          },
          relationships: {
            goods_nomenclatures: Hash,
          },
        },
      }
    end

    it { is_expected.to match_json_expression(expected_pattern) }
  end
end
