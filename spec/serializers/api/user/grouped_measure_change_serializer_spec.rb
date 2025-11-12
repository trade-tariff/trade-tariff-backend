require 'rails_helper'

RSpec.describe Api::User::GroupedMeasureChangeSerializer do
  subject(:serialized) { described_class.new(serializable, serializer_options).serializable_hash }

  let(:geographical_area) { create(:geographical_area, :with_description, geographical_area_id: 'GB') }
  let(:excluded_area_1) { create(:geographical_area, :with_description, geographical_area_id: 'FR') }
  let(:excluded_area_2) { create(:geographical_area, :with_description, geographical_area_id: 'DE') }
  let(:commodity_1) { create(:goods_nomenclature, goods_nomenclature_item_id: '1234567890') }
  let(:commodity_2) { create(:goods_nomenclature, goods_nomenclature_item_id: '9876543210') }

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

    it 'has the correct id' do
      expect(serialized[:data][:id]).to eq('import_GB_DE-FR')
    end

    it 'has the correct type' do
      expect(serialized[:data][:type]).to eq(:grouped_measure_change)
    end

    it 'has the correct attributes' do
      expect(serialized[:data][:attributes]).to eq(
        trade_direction: 'import',
        count: 5,
      )
    end

    context 'with relationships included' do
      let(:serializer_options) do
        {
          include: %w[
            geographical_area
            excluded_countries
            grouped_measure_commodity_changes
            grouped_measure_commodity_changes.commodity
          ],
        }
      end

      it 'includes geographical area relationship' do
        geographical_area # Ensure it's created
        expect(serialized[:data][:relationships]).to have_key(:geographical_area)
        expect(serialized[:data][:relationships][:geographical_area]).to eq(
          data: {
            id: 'GB',
            type: :geographical_area,
          },
        )
      end

      it 'includes excluded countries relationship' do
        excluded_area_1 # Ensure they're created
        excluded_area_2
        expect(serialized[:data][:relationships]).to have_key(:excluded_countries)
        excluded_countries_data = serialized[:data][:relationships][:excluded_countries][:data]
        expect(excluded_countries_data).to contain_exactly(
          { id: 'DE', type: :geographical_area },
          { id: 'FR', type: :geographical_area },
        )
      end

      it 'includes grouped measure commodity changes relationship' do
        expect(serialized[:data][:relationships]).to have_key(:grouped_measure_commodity_changes)
        expect(serialized[:data][:relationships][:grouped_measure_commodity_changes]).to eq(
          data: [
            { id: 'import_GB_DE-FR_1234567890', type: :grouped_measure_commodity_change },
            { id: 'import_GB_DE-FR_9876543210', type: :grouped_measure_commodity_change },
          ],
        )
      end

      it 'includes the related geographical area data' do
        geographical_area # Ensure it's created
        expect(serialized[:included]).to include(
          id: 'GB',
          type: :geographical_area,
          attributes: hash_including(
            geographical_area_id: 'GB',
          ),
        )
      end

      it 'includes the excluded countries data' do
        excluded_area_1 # Ensure they're created
        excluded_area_2
        excluded_countries = serialized[:included].select { |item| item[:type] == :geographical_area && %w[FR DE].include?(item[:id]) }
        expect(excluded_countries.length).to eq(2)

        france = excluded_countries.find { |item| item[:id] == 'FR' }
        germany = excluded_countries.find { |item| item[:id] == 'DE' }

        expect(france[:attributes]).to include(geographical_area_id: 'FR')
        expect(germany[:attributes]).to include(geographical_area_id: 'DE')
      end

      it 'includes the grouped measure commodity changes data' do
        commodity_changes = serialized[:included].select { |item| item[:type] == :grouped_measure_commodity_change }
        expect(commodity_changes.length).to eq(2)

        first_change = commodity_changes.find { |item| item[:id] == 'import_GB_DE-FR_1234567890' }
        second_change = commodity_changes.find { |item| item[:id] == 'import_GB_DE-FR_9876543210' }

        expect(first_change[:attributes]).to include(count: 3)
        expect(second_change[:attributes]).to include(count: 2)
      end

      it 'includes the commodity data' do
        commodity_1 # Ensure they're created
        commodity_2
        commodities = serialized[:included].select { |item| item[:type] == :commodity }
        expect(commodities.length).to eq(2)

        first_commodity = commodities.find { |item| item[:attributes][:goods_nomenclature_item_id] == '1234567890' }
        second_commodity = commodities.find { |item| item[:attributes][:goods_nomenclature_item_id] == '9876543210' }

        expect(first_commodity).to be_present
        expect(second_commodity).to be_present
        expect(first_commodity[:attributes]).to include(goods_nomenclature_item_id: '1234567890')
        expect(second_commodity[:attributes]).to include(goods_nomenclature_item_id: '9876543210')
      end
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
