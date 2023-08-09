RSpec.describe Footnote do
  describe '#code' do
    let(:footnote) { build :footnote }

    it 'returns conjuction of footnote type id and footnote id' do
      expect(footnote.code).to eq [footnote.footnote_type_id, footnote.footnote_id].join
    end
  end
end
