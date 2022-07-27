RSpec.describe Api::Beta::GoodsNomenclatureFilterGeneratorService do
  describe '#call' do
    subject(:call) { described_class.new(filters).call }

    context 'when generating filters for static filters' do
      let(:filters) do
        {
          'goods_nomenclature_class' => 'Commodity',
        }
      end

      let(:expected_filters) do
        [
          {
            term: { goods_nomenclature_class: 'Commodity' },
          },
        ]
      end

      it { is_expected.to eq(expected_filters) }
    end

    context 'when generating filters for dynamic filters' do
      let(:filters) do
        {
          'animal_product_state' => 'live',
        }
      end

      let(:expected_filters) do
        [
          {
            terms: {
              boost: 1,
              filter_animal_product_state: [
                'chilled|dried, salted, smoked or in brine|fresh|frozen|live|prepared or preserved',
                'chilled|dried, salted, smoked or in brine|fresh|frozen|live',
                'chilled|fresh|frozen|live',
                'chilled|fresh|live',
                'fresh|live',
                'live',
              ],
            },
          },
        ]
      end

      it { is_expected.to eq(expected_filters) }
    end

    context 'when generating filters for dynamic filters that have a custom boost' do
      let(:filters) do
        {
          'entity' => 'live animal',
        }
      end

      let(:expected_filters) do
        [
          {
            terms: {
              boost: 10,
              filter_entity: Array,
            },
          },
        ]
      end

      it { is_expected.to match_json_expression(expected_filters) }
    end
  end
end
