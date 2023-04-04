RSpec.describe Api::V2::Headings::CommoditySerializer do
  subject(:serializer) { described_class.new(serializable).serializable_hash.as_json }

  let(:serializable) do
    Hashie::TariffMash.new(
      leaf:,
      producline_suffix:,
    )
  end

  describe '#serializable_hash' do
    context 'when the commodity is declarable' do
      let(:leaf) { true }
      let(:producline_suffix) { '80' }

      it { expect(serializer.dig('data', 'attributes', 'declarable')).to eq(true) }
    end

    context 'when the commodity is not declarable' do
      let(:leaf) { false }
      let(:producline_suffix) { '80' }

      it { expect(serializer.dig('data', 'attributes', 'declarable')).to eq(false) }
    end
  end
end
