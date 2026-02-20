RSpec.describe LabelService do
  let(:batch) { [goods_nomenclature] }
  let(:goods_nomenclature) do
    instance_double(
      GoodsNomenclature,
      goods_nomenclature_sid: 1,
      goods_nomenclature_item_id: '0101210000',
      ancestor_chain_description: 'Live animals >> Horses >> Pure-bred breeding animals',
      goods_nomenclature_label: nil,
      as_json: { 'goods_nomenclature_item_id' => '0101210000' },
    )
  end
  let(:ai_client) { instance_double(OpenaiClient) }
  let(:label) { instance_double(GoodsNomenclatureLabel) }
  let(:label_context) do
    'Generate labels for the following UK trade tariff commodities. Return JSON with a "data" array.'
  end

  before do
    allow(TradeTariffBackend).to receive(:ai_client).and_return(ai_client)
    allow(GoodsNomenclatureLabel).to receive(:build).and_return(label)
    allow(GoodsNomenclatureSelfText).to receive(:where).and_return(
      instance_double(Sequel::Dataset, select_map: []),
    )
    create(:admin_configuration, name: 'label_context', value: label_context, area: 'classification')
  end

  describe '#call' do
    let(:ai_response) do
      {
        'data' => [
          {
            'commodity_code' => '0101210000',
            'description' => 'Purebred horses for breeding',
            'known_brands' => [],
            'colloquial_terms' => ['stud horses'],
            'synonyms' => ['breeding horses'],
          },
        ],
      }
    end

    before do
      allow(ai_client).to receive(:call).and_return(ai_response)
    end

    it 'calls the AI client with the labelling context' do
      described_class.new(batch).call

      expect(ai_client).to have_received(:call) do |context|
        expect(context).to include('Generate labels for the following UK trade tariff commodities')
      end
    end

    it 'builds labels for each item returned by the AI' do
      described_class.new(batch).call

      expect(GoodsNomenclatureLabel).to have_received(:build).with(
        goods_nomenclature,
        ai_response['data'].first,
        contextual_description: 'Live animals >> Horses >> Pure-bred breeding animals',
      )
    end

    it 'returns an array of labels' do
      result = described_class.new(batch).call

      expect(result).to eq([label])
    end

    context 'when the AI returns empty data' do
      let(:ai_response) { {} }

      it 'returns an empty array' do
        result = described_class.new(batch).call

        expect(result).to eq([])
      end
    end

    context 'when the AI returns nil data' do
      let(:ai_response) { { 'data' => nil } }

      it 'returns an empty array' do
        result = described_class.new(batch).call

        expect(result).to eq([])
      end
    end

    context 'when the AI returns a string with embedded JSON' do
      let(:ai_response) do
        'Here is the response: {"data": [{"commodity_code": "0101210000", "description": "Horses"}]}'
      end

      it 'extracts the JSON and builds labels' do
        described_class.new(batch).call

        expect(GoodsNomenclatureLabel).to have_received(:build)
      end
    end

    context 'when the AI returns an Array directly' do
      let(:ai_response) do
        [{ 'commodity_code' => '0101210000', 'description' => 'Horses' }]
      end

      it 'uses the array as data and builds labels' do
        described_class.new(batch).call

        expect(GoodsNomenclatureLabel).to have_received(:build)
      end
    end

    context 'when the AI returns a non-parseable string' do
      let(:ai_response) { 'Unparseable' }

      it 'returns an empty array' do
        result = described_class.new(batch).call

        expect(result).to eq([])
      end

      it 'logs an error' do
        allow(Rails.logger).to receive(:error)

        described_class.new(batch).call

        expect(Rails.logger).to have_received(:error).with(/unexpected response type/)
      end
    end
  end

  describe '.call' do
    let(:ai_response) { { 'data' => [] } }

    before do
      allow(ai_client).to receive(:call).and_return(ai_response)
    end

    it 'creates an instance and calls it' do
      expect(described_class.call(batch)).to eq([])
    end

    it 'instruments the API call' do
      allow(LabelGenerator::Instrumentation).to receive(:api_call).and_call_original

      described_class.call(batch)

      expect(LabelGenerator::Instrumentation).to have_received(:api_call).with(
        batch_size: 1,
        model: TradeTariffBackend.ai_model,
        page_number: nil,
      )
    end
  end
end
