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

  describe '.configuration_for_server' do
    subject { described_class.config_for_server['persistent'] }

    it { is_expected.to include 'action.auto_create_index' => false }
  end

  describe '.update_server_config' do
    before do
      stub_request(:put, "#{elasticsearch_url}/_cluster/settings")
        .to_return(status: 200)

      described_class.update_server_config
    end

    let(:elasticsearch_url) do
      ENV.fetch('ELASTICSEARCH_URL', 'http://localhost:9200')
    end

    it 'PUTs the config onto the server' do
      expect(WebMock).to \
        have_requested(:put, "#{elasticsearch_url}/_cluster/settings")
          .with(body: described_class.config_for_server.to_json)
    end
  end

  describe '#search' do
    let(:commodity) do
      create(:commodity, :with_description, description: 'test description')
    end

    let(:index) { Commodity.elasticsearch_index }

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
        expect(search_result).to be_kind_of Hashie::Mash
      end
    end

    context 'for newly defined index' do
      subject(:index_exists) do
        TradeTariffBackend.search_client.indices.exists index: index.name
      end

      before do
        TradeTariffBackend.search_client.drop_index index
        create :commodity, :with_description
      end

      after { TradeTariffBackend.search_client.create_index index }

      it 'does not create the index' do
        expect(index_exists).to be false
      end
    end
  end
end
