RSpec.describe CertificateFinderService do
  describe '#call' do
    subject(:call) { described_class.new(type, code, description).call }

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
      allow(SearchDescriptionNormaliserService).to receive(:new).and_call_original
      call
    end

    it { is_expected.to be_empty }
    it { expect(SearchDescriptionNormaliserService).to have_received(:new).with(description) }

    context 'when searching by code and type' do
      let(:code) { certificate.certificate_code }
      let(:type) { certificate.certificate_type_code }

      it { is_expected.to all(be_a(Api::V2::CertificateSearch::CertificatePresenter)) }
      it { expect(call.first.certificate_code).to eq certificate.certificate_code }
      it { expect(call.first.certificate_type_code).to eq certificate.certificate_type_code }
    end

    context 'when searching by description' do
      let(:description) { certificate.description }

      it { is_expected.to all(be_a(Api::V2::CertificateSearch::CertificatePresenter)) }
      it { expect(call.first.certificate_code).to eq certificate.certificate_code }
      it { expect(SearchDescriptionNormaliserService).to have_received(:new).with(description) }
    end

    context 'when no measures are associated with the certificate' do
      let(:certificate) { create(:certificate, :with_description, certificate_type_code: 'X') }
      let(:code) { certificate.certificate_code }
      let(:type) { 'Y' }

      it { is_expected.to be_empty }
    end
  end
end
