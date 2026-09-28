RSpec.describe Api::User::GroupedMeasureChangeSerializer do
  subject(:serialized) { described_class.new(serializable, serializer_options).serializable_hash }

  let(:serializable) do
    TariffChanges::GroupedMeasureChange.new(
      trade_direction: 'import',
      count: 5,
      geographical_area_id: 'GB',
      excluded_geographical_area_ids: %w[FR DE],
      commodities: [
        { goods_nomenclature_item_id: '1234567890', count: 3 },
        { goods_nomenclature_item_id: '9876543210', count: 2 },
      ],
    )
  end

  let(:serializer_options) { {} }

  describe '#serializable_hash' do
    it 'returns the correct structure' do
      expect(serialized[:data]).to include(
        id: 'import_GB_DE-FR',
        type: :grouped_measure_change,
        attributes: {
          trade_direction: 'import',
          count: 5,
        },
      )
    end

    context 'without excluded geographical areas' do
      let(:serializable) do
        TariffChanges::GroupedMeasureChange.new(
          trade_direction: 'export',
          count: 3,
          geographical_area_id: 'GB',
          excluded_geographical_area_ids: [],
        )
      end

      let(:serializer_options) do
        { include: %w[geographical_area excluded_countries] }
      end

      it 'handles empty excluded countries correctly' do
        expect(serialized[:data][:relationships][:excluded_countries]).to eq(
          data: [],
        )
      end
    end

    context 'without geographical area' do
      let(:serializable) do
        TariffChanges::GroupedMeasureChange.new(
          trade_direction: 'import',
          count: 2,
          geographical_area_id: nil,
          excluded_geographical_area_ids: [],
        )
      end

      let(:serializer_options) do
        { include: %w[geographical_area] }
      end

      it 'handles nil geographical area correctly' do
        expect(serialized[:data][:relationships][:geographical_area]).to eq(
          data: nil,
        )
      end
    end
  end
end
