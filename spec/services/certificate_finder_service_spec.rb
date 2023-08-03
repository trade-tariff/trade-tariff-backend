RSpec.describe CertificateFinderService do
  describe '#call' do
    subject(:call) { described_class.new(code, type, description).call }

    let(:code) { nil }
    let(:type) { nil }
    let(:description) { nil }

    let(:certificate) { create(:certificate, :with_description) }

    let(:measure) do
      create(
        :measure,
        :with_base_regulation,
        goods_nomenclature: create(:goods_nomenclature),
      )
    end

    before do
      create(:measure_condition, certificate:, measure:)
    end

    it { is_expected.to be_empty }

    context 'when searching by code' do
      let(:code) { certificate.certificate_code }

      it { is_expected.to all(be_a(Api::V2::CertificateSearch::CertificatePresenter)) }
      it { expect(call.first.certificate_code).to eq certificate.certificate_code }
    end

    context 'when searching by type' do
      let(:type) { certificate.certificate_type_code }

      it { is_expected.to all(be_a(Api::V2::CertificateSearch::CertificatePresenter)) }
      it { expect(call.first.certificate_code).to eq certificate.certificate_code }
    end

    context 'when searching by description' do
      let(:description) { certificate.description }

      it { is_expected.to all(be_a(Api::V2::CertificateSearch::CertificatePresenter)) }
      it { expect(call.first.certificate_code).to eq certificate.certificate_code }
    end
  end
end
