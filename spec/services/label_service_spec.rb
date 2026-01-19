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
            'goods_nomenclature_item_id' => '0101210000',
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

    context 'when the AI returns fewer results than expected' do
      let(:batch) { [goods_nomenclature, goods_nomenclature2] }
      let(:goods_nomenclature2) do
        instance_double(
          GoodsNomenclature,
          goods_nomenclature_item_id: '0101290000',
          classification_description: 'Other horses',
          goods_nomenclature_label: nil,
          as_json: { 'goods_nomenclature_item_id' => '0101290000' },
        )
      end

      it 'logs the discrepancy' do
        allow(Rails.logger).to receive(:info)

        described_class.new(batch).call

        expect(Rails.logger).to have_received(:info).with('Expected 2 but got 1 labels')
      end
    end

    context 'when the AI returns all results' do
      it 'logs success' do
        allow(Rails.logger).to receive(:info)

        described_class.new(batch).call

        expect(Rails.logger).to have_received(:info).with('Successfully labelled 1 batch')
      end
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

    it 'logs the duration of the call' do
      allow(Rails.logger).to receive(:debug)
      allow(Rails.logger).to receive(:info)

      described_class.call(batch)

      expect(Rails.logger).to have_received(:debug).with(/LabelService call took \d+\.\d+ seconds/)
    end
  end
end
