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
      create :commodity, :with_description, description: 'test description'
    end

    let(:search_result) do
      TradeTariffBackend.search_client.search q: 'test', index: TradeTariffBackend.search_index_for('search', commodity).name
    end

    it 'searches in supplied index' do
      expect(search_result.hits.total.value).to be >= 1
    end

    it 'returns expected results' do
      expect(search_result.hits.hits.map do |hit|
        hit._source.goods_nomenclature_item_id
      end).to include commodity.goods_nomenclature_item_id
    end

    it 'returns results wrapped in Hashie::Mash structure' do
      expect(search_result).to be_kind_of Hashie::Mash
    end
  end
end
