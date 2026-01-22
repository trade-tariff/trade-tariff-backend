RSpec.describe LabelService do
  let(:batch) { [goods_nomenclature] }
  let(:goods_nomenclature) do
    instance_double(
      GoodsNomenclature,
      goods_nomenclature_item_id: '0101210000',
      classification_description: 'Pure-bred breeding animals - Horses',
      goods_nomenclature_label: nil,
      as_json: { 'goods_nomenclature_item_id' => '0101210000' },
    )
  end
  let(:ai_client) { instance_double(OpenaiClient) }
  let(:label) { instance_double(GoodsNomenclatureLabel) }

  before do
    allow(TradeTariffBackend).to receive(:ai_client).and_return(ai_client)
    allow(GoodsNomenclatureLabel).to receive(:build).and_return(label)
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
        expect(context).to include(I18n.t('contexts.label_commodity.instructions'))
      end
    end

    it 'builds labels for each item returned by the AI' do
      described_class.new(batch).call

      expect(GoodsNomenclatureLabel).to have_received(:build).with(
        goods_nomenclature,
        ai_response['data'].first,
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
