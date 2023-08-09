RSpec.describe AdditionalCodeFinderService do
  describe '#call' do
    subject(:call) { described_class.new(code, type, description).call }

    let(:code) { nil }
    let(:type) { nil }
    let(:description) { nil }

    let(:additional_code) { create(:additional_code, :with_description) }

    let(:measure) do
      create(
        :measure,
        :with_base_regulation,
        additional_code:,
        goods_nomenclature: create(:goods_nomenclature),
      )
    end

    before do
      measure
      allow(SearchDescriptionNormaliserService).to receive(:new).and_call_original
      call
    end

    it { is_expected.to be_empty }
    it { expect(SearchDescriptionNormaliserService).to have_received(:new).with(description) }

    context 'when searching by code' do
      let(:code) { additional_code.additional_code }
      let(:type) { additional_code.additional_code_type_id }

      it { is_expected.to all(be_a(Api::V2::AdditionalCodeSearch::AdditionalCodePresenter)) }
      it { expect(call.first.additional_code).to eq additional_code.additional_code }
    end

    context 'when searching by description' do
      let(:description) { additional_code.description }

      it { is_expected.to all(be_a(Api::V2::AdditionalCodeSearch::AdditionalCodePresenter)) }
      it { expect(call.first.additional_code).to eq additional_code.additional_code }
      it { expect(SearchDescriptionNormaliserService).to have_received(:new).with(description) }
    end
  end
end
