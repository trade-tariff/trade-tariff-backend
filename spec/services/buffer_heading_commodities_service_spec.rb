RSpec.describe BufferHeadingCommoditiesService do
  subject(:service) { described_class.new }

  describe '#call' do
    around do |example|
      create(:heading, :grouping, goods_nomenclature_item_id: '0101000000')

      Thread.current[:heading_commodities] = 'foo'
      example.call
      Thread.current[:heading_commodities] = nil # Protect callers of #children
    end

    it 'preloads heading commodities for the duration of the call' do
      service.call do
        expect(Thread.current[:heading_commodities]).to eq('0101' => [])
      end
    end

    it 'does not change the value of the initial headings commodities' do
      service.call

      expect(Thread.current[:heading_commodities]).to eq('foo')
    end

    context 'when the block call fails' do
      let(:block) { proc { raise ArgumentError } }

      # rubocop:disable RSpec/MultipleExpectations
      it 'does not change the value of the initial headings commodities' do
        expect { service.call(&block) }.to raise_error(ArgumentError)
        expect(Thread.current[:heading_commodities]).to eq('foo')
      end
      # rubocop:enable RSpec/MultipleExpectations
    end
  end
end
