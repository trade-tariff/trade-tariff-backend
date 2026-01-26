RSpec.describe TradeTariffBackend::SearchClient do
  describe '.server_namespace' do
    subject { described_class.server_namespace }

    it { is_expected.to eql 'tariff-test' }

    context 'when overridden' do
      before do
        orig_namespace # trigger caching in method
        described_class.server_namespace = 'overridden'
      end

      after { described_class.server_namespace = orig_namespace }

      let(:orig_namespace) { described_class.server_namespace }

      it { is_expected.to eql 'overridden' }
    end
  end

  describe '.search_operation_options' do
    subject { described_class.search_operation_options }

    it { is_expected.to be_instance_of Hash }
  end

  describe '#search' do
    let(:commodity) do
      create(:commodity, :with_description, description: 'test description').tap do |model|
        index_model(model)
      end
    end

    let(:index) { Search::CommodityIndex.new }

    let(:search_result) do
      TradeTariffBackend.search_client.search q: 'test', index: index.name
    end

    let(:search_result_commodity_ids) do
      search_result.hits.hits.map(&:_source).map(&:goods_nomenclature_item_id)
    end

    context 'with existing index' do
      before { commodity }

      it 'searches in supplied index' do
        expect(search_result.hits.total.value).to be >= 1
      end

      it 'returns expected results' do
        expect(search_result_commodity_ids).to include commodity.goods_nomenclature_item_id
      end

      it 'returns results wrapped in Hashie::Mash structure' do
        expect(search_result).to be_a Hashie::Mash
      end
    end
  end
end
