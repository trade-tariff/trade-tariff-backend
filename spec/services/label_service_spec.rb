RSpec.describe LabelService do
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

  before do
    allow(TradeTariffBackend).to receive(:ai_client).and_return(ai_client)
    allow(GoodsNomenclatureLabel).to receive(:build).and_return(label)
    allow(GoodsNomenclatureSelfText).to receive(:where).and_return(
      instance_double(Sequel::Dataset, select_map: []),
    )
    create(
      :admin_configuration,
      name: 'label_context',
      value: 'Generate labels for the following UK trade tariff commodities. Return JSON with a "data" array.',
      area: 'classification',
    )
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
      described_class.new([goods_nomenclature]).call

      expect(ai_client).to have_received(:call) do |context|
        expect(context).to include('Generate labels for the following UK trade tariff commodities')
      end
    end

    it 'builds labels for each item returned by the AI' do
      described_class.new([goods_nomenclature]).call

      expect(GoodsNomenclatureLabel).to have_received(:build).with(
        goods_nomenclature,
        ai_response['data'].first,
        contextual_description: 'Live animals >> Horses >> Pure-bred breeding animals',
      )
    end

    context 'with a generic commodity description' do
      let(:goods_nomenclature) do
        instance_double(
          GoodsNomenclature,
          goods_nomenclature_sid: 1,
          goods_nomenclature_item_id: '8517130000',
          ancestor_chain_description: 'Telephone sets >> Smartphones',
          goods_nomenclature_label: nil,
          as_json: { 'goods_nomenclature_item_id' => '8517130000' },
        )
      end
      let(:ai_response) do
        {
          'data' => [
            {
              'commodity_code' => '8517130000',
              'description' => 'Smartphones',
              'known_brands' => %w[Apple Samsung],
              'colloquial_terms' => [],
              'synonyms' => ['mobile phones'],
            },
          ],
        }
      end

      it 'keeps brand aliases absent from the description' do
        described_class.new([goods_nomenclature]).call

        expect(GoodsNomenclatureLabel).to have_received(:build).with(
          goods_nomenclature,
          hash_including('known_brands' => %w[Apple Samsung]),
          contextual_description: 'Telephone sets >> Smartphones',
        )
      end

      it 'persists aliases in both label representations' do
        commodity = create(:commodity, goods_nomenclature_item_id: '8517130000')
        allow(commodity).to receive(:ancestor_chain_description).and_return('Telephone sets >> Smartphones')
        allow(GoodsNomenclatureLabel).to receive(:build).and_call_original

        generated = described_class.call([commodity]).first
        generated.save
        stored = GoodsNomenclatureLabel[commodity.goods_nomenclature_sid]

        expect(stored.known_brands).to eq(%w[Apple Samsung])
        expect(stored.labels['known_brands']).to eq(%w[Apple Samsung])
      end
    end

    context 'when the AI returns more than eight synonyms or colloquial terms' do
      let(:ai_response) do
        {
          'data' => [
            {
              'commodity_code' => '0101210000',
              'description' => 'Purebred horses for breeding',
              'known_brands' => [],
              'synonyms' => (1..9).map { |index| "synonym #{index}" },
              'colloquial_terms' => (1..10).map { |index| "term #{index}" },
            },
          ],
        }
      end

      it 'caps the synonym list at the first eight entries' do
        described_class.new([goods_nomenclature]).call

        expect(GoodsNomenclatureLabel).to have_received(:build).with(
          goods_nomenclature,
          hash_including('synonyms' => (1..8).map { |index| "synonym #{index}" }),
          contextual_description: 'Live animals >> Horses >> Pure-bred breeding animals',
        )
      end

      it 'caps the colloquial term list at the first eight entries' do
        described_class.new([goods_nomenclature]).call

        expect(GoodsNomenclatureLabel).to have_received(:build).with(
          goods_nomenclature,
          hash_including('colloquial_terms' => (1..8).map { |index| "term #{index}" }),
          contextual_description: 'Live animals >> Horses >> Pure-bred breeding animals',
        )
      end
    end

    context 'when the AI returns blank or duplicate entries' do
      let(:ai_response) do
        {
          'data' => [
            {
              'commodity_code' => '0101210000',
              'description' => 'Purebred horses for breeding',
              'known_brands' => ['', '  ', 'Horses', 'Horses'],
              'colloquial_terms' => ['stud horses', ''],
              'synonyms' => ['duplicate', '', 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'duplicate'],
            },
          ],
        }
      end

      it 'removes blank and duplicate entries before the cap' do
        described_class.new([goods_nomenclature]).call

        expect(GoodsNomenclatureLabel).to have_received(:build).with(
          goods_nomenclature,
          hash_including(
            'known_brands' => %w[Horses],
            'colloquial_terms' => ['stud horses'],
            'synonyms' => %w[duplicate a b c d e f g],
          ),
          contextual_description: 'Live animals >> Horses >> Pure-bred breeding animals',
        )
      end
    end

    it 'returns an array of labels' do
      result = described_class.new([goods_nomenclature]).call

      expect(result).to eq([label])
    end

    context 'when the AI returns empty data' do
      let(:ai_response) { {} }

      it 'returns an empty array' do
        result = described_class.new([goods_nomenclature]).call

        expect(result).to eq([])
      end
    end

    context 'when the AI returns nil data' do
      let(:ai_response) { { 'data' => nil } }

      it 'returns an empty array' do
        result = described_class.new([goods_nomenclature]).call

        expect(result).to eq([])
      end
    end

    context 'when the AI returns a string with embedded JSON' do
      let(:ai_response) do
        'Here is the response: {"data": [{"commodity_code": "0101210000", "description": "Horses"}]}'
      end

      it 'extracts the JSON and builds labels' do
        described_class.new([goods_nomenclature]).call

        expect(GoodsNomenclatureLabel).to have_received(:build)
      end
    end

    context 'when the AI returns an Array directly' do
      let(:ai_response) do
        [{ 'commodity_code' => '0101210000', 'description' => 'Horses' }]
      end

      it 'uses the array as data and builds labels' do
        described_class.new([goods_nomenclature]).call

        expect(GoodsNomenclatureLabel).to have_received(:build)
      end
    end

    context 'when the AI returns a non-parseable string' do
      let(:ai_response) { 'Unparseable' }

      it 'returns an empty array' do
        result = described_class.new([goods_nomenclature]).call

        expect(result).to eq([])
      end

      it 'logs an error' do
        allow(Rails.logger).to receive(:error)

        described_class.new([goods_nomenclature]).call

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
      expect(described_class.call([goods_nomenclature])).to eq([])
    end

    it 'instruments the API call' do
      allow(LabelGenerator::Instrumentation).to receive(:api_call).and_call_original

      described_class.call([goods_nomenclature])

      expect(LabelGenerator::Instrumentation).to have_received(:api_call).with(
        batch_size: 1,
        model: 'gpt-5.4',
        page_number: nil,
      )
    end
  end
end
