RSpec.describe Footnote do
  describe '#id' do
    let(:footnote) { build :footnote }

    it 'returns conjuction of footnote type id and footnote id' do
      expect(footnote.id).to eq [footnote.footnote_type_id, footnote.footnote_id].join
    end
  end

  describe '.with_footnote_types_and_ids' do
    subject(:dataset) { described_class.with_footnote_types_and_ids(footnote_types_and_ids) }

    before do
      create(
        :footnote,
        footnote_type_id: 'Y',
        footnote_id: '123',
      )
      create(
        :footnote,
        footnote_type_id: 'N',
        footnote_id: '456',
      )
      create(
        :footnote,
        footnote_type_id: 'Z',
        footnote_id: '789',
      )
    end

    context 'when footnote_types_and_ids is empty' do
      let(:footnote_types_and_ids) { [] }

      it { expect(dataset.pluck(:footnote_id)).to eq %w[123 456 789] }
      it { expect(dataset.pluck(:footnote_type_id)).to eq %w[Y N Z] }
    end

    context 'when footnote_types_and_ids is present' do
      let(:footnote_types_and_ids) do
        [
          %w[Y 123],
          %w[N 456],
        ]
      end

      it { expect(dataset.pluck(:footnote_id)).to eq %w[123 456] }
      it { expect(dataset.pluck(:footnote_type_id)).to eq %w[Y N] }
    end
  end
end
