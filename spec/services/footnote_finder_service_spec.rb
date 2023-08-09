RSpec.describe FootnoteFinderService do
  describe '#call' do
    subject(:call) { described_class.new(type, id, description).call }

    let(:type) { nil }
    let(:id) { nil }
    let(:description) { nil }

    before do
      goods_nomenclature = create(:goods_nomenclature)
      measure = create(
        :measure,
        :with_base_regulation,
        goods_nomenclature: create(:goods_nomenclature),
      )

      create( # included
        :footnote,
        :with_description,
        :with_goods_nomenclature_association,
        goods_nomenclature:,
        footnote_type_id: 'ME',
        footnote_id: '123',
        description: 'abc',
      )

      create( # included
        :footnote,
        :with_description,
        :with_measure_association,
        measure:,
        footnote_type_id: 'ME',
        footnote_id: '123',
        description: 'abc',
      )

      create( # excluded
        :footnote,
        :with_description,
        :with_goods_nomenclature_association,
        goods_nomenclature:,
        footnote_type_id: 'XY',
        footnote_id: '234',
        description: 'def',
      )

      create( # excluded
        :footnote,
        :with_description,
        :with_measure_association,
        measure:,
        footnote_type_id: 'XY',
        footnote_id: '234',
        description: 'def',
      )

      allow(SearchDescriptionNormaliserService).to receive(:new).and_call_original
      call
    end

    it { is_expected.to be_empty }
    it { expect(SearchDescriptionNormaliserService).to have_received(:new).with(nil) }

    context 'when searching by id and type' do
      let(:type) { 'ME' }
      let(:id) { '123' }

      it { is_expected.to all(be_a(Api::V2::FootnoteSearch::FootnotePresenter)) }
      it { expect(call.first.goods_nomenclatures.count).to eq 2 }
      it { expect(call.pluck(:footnote_id)).to eq %w[123] }
      it { expect(call.pluck(:footnote_type_id)).to eq %w[ME] }
      it { expect(SearchDescriptionNormaliserService).to have_received(:new).with(nil) }
    end

    context 'when searching by description' do
      let(:description) { 'abc' }

      it { is_expected.to all(be_a(Api::V2::FootnoteSearch::FootnotePresenter)) }
      it { expect(call.first.goods_nomenclatures.count).to eq 2 }
      it { expect(call.count).to eq 1 }
      it { expect(call.map(&:description)).to eq %w[abc] }
      it { expect(SearchDescriptionNormaliserService).to have_received(:new).with('abc') }
    end

    context 'when no measures are associated with the footnote' do
      let(:type) { 'Y' }
      let(:id) { '123' }

      it { is_expected.to be_empty }
      it { expect(SearchDescriptionNormaliserService).to have_received(:new).with(nil) }
    end
  end
end
