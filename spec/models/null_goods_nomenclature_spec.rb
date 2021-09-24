RSpec.describe NullGoodsNomenclature do
  let(:subject) { described_class.new }

  describe '#description' do
    it 'returns empty string' do
      expect(subject.description).to eq('')
    end
  end
end
