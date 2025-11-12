require 'rails_helper'

RSpec.describe TariffChanges::GroupedMeasureChange do
  subject(:grouped_measure_change) do
    described_class.new(
      trade_direction: 'import',
      count: 5,
      geographical_area_id: 'GB',
      excluded_geographical_area_ids: excluded_area_ids,
    )
  end

  let(:excluded_area_ids) { %w[FR DE] }
  let!(:geographical_area) { create(:geographical_area, :with_description, geographical_area_id: 'GB') }
  let!(:excluded_area_1) { create(:geographical_area, :with_description, geographical_area_id: 'FR') }
  let!(:excluded_area_2) { create(:geographical_area, :with_description, geographical_area_id: 'DE') }

  describe '#geographical_area' do
    context 'when geographical_area_id is present' do
      it 'returns the corresponding GeographicalArea' do
        expect(grouped_measure_change.geographical_area).to eq(geographical_area)
      end

      it 'memoizes the result' do
        allow(GeographicalArea).to receive(:find).and_call_original
        2.times { grouped_measure_change.geographical_area }
        expect(GeographicalArea).to have_received(:find).once
      end
    end

    context 'when geographical_area_id is nil' do
      subject(:grouped_measure_change) do
        described_class.new(
          trade_direction: 'import',
          count: 5,
          geographical_area_id: nil,
          excluded_geographical_area_ids: [],
        )
      end

      it 'returns nil' do
        expect(grouped_measure_change.geographical_area).to be_nil
      end
    end

    context 'when geographical_area_id is blank' do
      subject(:grouped_measure_change) do
        described_class.new(
          trade_direction: 'import',
          count: 5,
          geographical_area_id: '',
          excluded_geographical_area_ids: [],
        )
      end

      it 'returns nil' do
        expect(grouped_measure_change.geographical_area).to be_nil
      end
    end
  end

  describe '#excluded_geographical_areas' do
    context 'when excluded_geographical_area_ids is an array' do
      it 'returns the corresponding GeographicalAreas' do
        result = grouped_measure_change.excluded_geographical_areas
        expect(result).to contain_exactly(excluded_area_1, excluded_area_2)
      end

      it 'memoizes the result' do
        allow(GeographicalArea).to receive(:where).and_call_original
        2.times { grouped_measure_change.excluded_geographical_areas }
        expect(GeographicalArea).to have_received(:where).once
      end
    end

    context 'when excluded_geographical_area_ids is a single string' do
      let(:excluded_area_ids) { 'FR' }

      it 'converts to array and returns the corresponding GeographicalArea' do
        result = grouped_measure_change.excluded_geographical_areas
        expect(result).to contain_exactly(excluded_area_1)
      end
    end

    context 'when excluded_geographical_area_ids contains nil values' do
      let(:excluded_area_ids) { ['FR', nil, 'DE', nil] }

      it 'filters out nil values and returns valid GeographicalAreas' do
        result = grouped_measure_change.excluded_geographical_areas
        expect(result).to contain_exactly(excluded_area_1, excluded_area_2)
      end
    end

    context 'when excluded_geographical_area_ids is nil' do
      let(:excluded_area_ids) { nil }

      it 'returns an empty array' do
        expect(grouped_measure_change.excluded_geographical_areas).to eq([])
      end
    end

    context 'when excluded_geographical_area_ids is blank' do
      let(:excluded_area_ids) { [] }

      it 'returns an empty array' do
        expect(grouped_measure_change.excluded_geographical_areas).to eq([])
      end
    end

    context 'when excluded_geographical_area_ids contains only nil values' do
      let(:excluded_area_ids) { [nil, nil] }

      it 'returns an empty array' do
        expect(grouped_measure_change.excluded_geographical_areas).to eq([])
      end
    end

    context 'when excluded_geographical_area_ids contains non-existent IDs' do
      let(:excluded_area_ids) { %w[FR NONEXISTENT DE] }

      it 'returns only the existing GeographicalAreas' do
        result = grouped_measure_change.excluded_geographical_areas
        expect(result).to contain_exactly(excluded_area_1, excluded_area_2)
      end
    end

    context 'when excluded_geographical_area_ids is an empty string' do
      let(:excluded_area_ids) { '' }

      it 'returns an empty array' do
        expect(grouped_measure_change.excluded_geographical_areas).to eq([])
      end
    end
  end

  describe 'attributes' do
    it 'has the expected attributes' do
      expect(grouped_measure_change.trade_direction).to eq('import')
      expect(grouped_measure_change.count).to eq(5)
      expect(grouped_measure_change.geographical_area_id).to eq('GB')
      expect(grouped_measure_change.excluded_geographical_area_ids).to eq(%w[FR DE])
    end

    it 'can be initialized with minimal attributes' do
      minimal_change = described_class.new(trade_direction: 'export')
      expect(minimal_change.trade_direction).to eq('export')
      expect(minimal_change.count).to be_nil
      expect(minimal_change.geographical_area_id).to be_nil
      expect(minimal_change.excluded_geographical_area_ids).to be_nil
    end

    it 'initializes commodities as empty array by default' do
      change = described_class.new(trade_direction: 'import')
      expect(change.commodities).to eq([])
    end

    it 'allows commodities to be set during initialization' do
      commodities = [
        { goods_nomenclature_item_id: '1234567890', count: 3 },
        { goods_nomenclature_item_id: '9876543210', count: 2 },
      ]

      change = described_class.new(
        trade_direction: 'import',
        commodities: commodities,
      )

      expect(change.commodities).to eq(commodities)
    end
  end

  describe '.from_id' do
    context 'with complete id' do
      let(:id) { 'import_GB_FR-DE' }

      it 'parses the id correctly' do
        result = described_class.from_id(id)

        expect(result.trade_direction).to eq('import')
        expect(result.geographical_area_id).to eq('GB')
        expect(result.excluded_geographical_area_ids).to eq(%w[FR DE])
      end
    end

    context 'with id without excluded areas' do
      let(:id) { 'export_US_' }

      it 'parses the id correctly with empty excluded areas' do
        result = described_class.from_id(id)

        expect(result.trade_direction).to eq('export')
        expect(result.geographical_area_id).to eq('US')
        expect(result.excluded_geographical_area_ids).to eq([])
      end
    end

    context 'with id with single excluded area' do
      let(:id) { 'both_CN_RU' }

      it 'parses the id correctly with single excluded area' do
        result = described_class.from_id(id)

        expect(result.trade_direction).to eq('both')
        expect(result.geographical_area_id).to eq('CN')
        expect(result.excluded_geographical_area_ids).to eq(%w[RU])
      end
    end

    context 'with malformed id' do
      let(:id) { 'import_GB' }

      it 'handles missing excluded areas part gracefully' do
        result = described_class.from_id(id)

        expect(result.trade_direction).to eq('import')
        expect(result.geographical_area_id).to eq('GB')
        expect(result.excluded_geographical_area_ids).to eq([])
      end
    end

    context 'with completely invalid id' do
      let(:id) { 'invalid' }

      it 'handles invalid id format gracefully' do
        result = described_class.from_id(id)

        expect(result.trade_direction).to eq('invalid')
        expect(result.geographical_area_id).to be_nil
        expect(result.excluded_geographical_area_ids).to eq([])
      end
    end

    context 'with empty id' do
      let(:id) { '' }

      it 'handles empty id gracefully' do
        result = described_class.from_id(id)

        expect(result.trade_direction).to be_nil
        expect(result.geographical_area_id).to be_nil
        expect(result.excluded_geographical_area_ids).to eq([])
      end
    end
  end

  describe '#id' do
    it 'generates correct id from attributes' do
      expect(grouped_measure_change.id).to eq('import_GB_DE-FR')
    end

    context 'when excluded_geographical_area_ids is empty' do
      let(:excluded_area_ids) { [] }

      it 'generates id without excluded areas' do
        expect(grouped_measure_change.id).to eq('import_GB_')
      end
    end

    context 'when excluded_geographical_area_ids has single item' do
      let(:excluded_area_ids) { %w[FR] }

      it 'generates id with single excluded area' do
        expect(grouped_measure_change.id).to eq('import_GB_FR')
      end
    end

    context 'when excluded_geographical_area_ids is unsorted' do
      let(:excluded_area_ids) { %w[ZZ AA MM] }

      it 'sorts the excluded areas in the id' do
        expect(grouped_measure_change.id).to eq('import_GB_AA-MM-ZZ')
      end
    end
  end

  describe '#trade_direction_code' do
    context 'when trade_direction is import' do
      subject(:grouped_measure_change) do
        described_class.new(trade_direction: 'import')
      end

      it 'returns the correct code' do
        expect(grouped_measure_change.trade_direction_code).to eq(0)
      end
    end

    context 'when trade_direction is export' do
      subject(:grouped_measure_change) do
        described_class.new(trade_direction: 'export')
      end

      it 'returns the correct code' do
        expect(grouped_measure_change.trade_direction_code).to eq(1)
      end
    end

    context 'when trade_direction is both' do
      subject(:grouped_measure_change) do
        described_class.new(trade_direction: 'both')
      end

      it 'returns the correct code' do
        expect(grouped_measure_change.trade_direction_code).to eq(2)
      end
    end

    context 'when trade_direction is invalid' do
      subject(:grouped_measure_change) do
        described_class.new(trade_direction: 'invalid')
      end

      it 'returns nil' do
        expect(grouped_measure_change.trade_direction_code).to be_nil
      end
    end
  end

  describe '#grouped_measure_commodity_changes' do
    subject(:grouped_measure_change) do
      described_class.new(
        trade_direction: 'import',
        geographical_area_id: 'GB',
        excluded_geographical_area_ids: %w[FR DE],
        commodities: commodities,
      )
    end

    let(:commodities) do
      [
        { goods_nomenclature_item_id: '1234567890', count: 3 },
        { goods_nomenclature_item_id: '9876543210', count: 2 },
      ]
    end

    it 'returns array of GroupedMeasureCommodityChange objects' do
      result = grouped_measure_change.grouped_measure_commodity_changes

      expect(result).to be_an(Array)
      expect(result.length).to eq(2)
      expect(result).to all(be_a(TariffChanges::GroupedMeasureCommodityChange))
    end

    it 'passes correct attributes to commodity changes' do
      result = grouped_measure_change.grouped_measure_commodity_changes

      first_commodity = result.first
      expect(first_commodity.goods_nomenclature_item_id).to eq('1234567890')
      expect(first_commodity.count).to eq(3)
      expect(first_commodity.grouped_measure_change_id).to eq(grouped_measure_change.id)

      second_commodity = result.second
      expect(second_commodity.goods_nomenclature_item_id).to eq('9876543210')
      expect(second_commodity.count).to eq(2)
      expect(second_commodity.grouped_measure_change_id).to eq(grouped_measure_change.id)
    end

    it 'memoizes the result' do
      allow(TariffChanges::GroupedMeasureCommodityChange).to receive(:new).and_call_original

      2.times { grouped_measure_change.grouped_measure_commodity_changes }

      expect(TariffChanges::GroupedMeasureCommodityChange).to have_received(:new).twice
    end

    context 'when commodities is empty' do
      let(:commodities) { [] }

      it 'returns empty array' do
        result = grouped_measure_change.grouped_measure_commodity_changes
        expect(result).to eq([])
      end
    end
  end

  describe '#add_commodity_change' do
    let(:commodity_attributes) { { goods_nomenclature_item_id: '5555555555', count: 1 } }

    it 'adds commodity to commodities array' do
      expect { grouped_measure_change.add_commodity_change(commodity_attributes) }
        .to change { grouped_measure_change.commodities.length }.by(1)

      expect(grouped_measure_change.commodities.last).to eq(commodity_attributes)
    end

    it 'resets memoized grouped_measure_commodity_changes' do
      # Access to trigger memoization
      initial_commodity_changes = grouped_measure_change.grouped_measure_commodity_changes
      expect(initial_commodity_changes.length).to eq(0)

      # Add a commodity
      grouped_measure_change.add_commodity_change(commodity_attributes)

      # Check that memoization was reset and new commodity is included
      updated_commodity_changes = grouped_measure_change.grouped_measure_commodity_changes
      expect(updated_commodity_changes.length).to eq(1)
      expect(updated_commodity_changes.first.goods_nomenclature_item_id).to eq('5555555555')
    end

    it 'returns the newly created GroupedMeasureCommodityChange' do
      result = grouped_measure_change.add_commodity_change(commodity_attributes)

      expect(result).to be_a(TariffChanges::GroupedMeasureCommodityChange)
      expect(result.goods_nomenclature_item_id).to eq('5555555555')
      expect(result.count).to eq(1)
      expect(result.grouped_measure_change_id).to eq(grouped_measure_change.id)
    end
  end

  describe 'ActiveModel integration' do
    it 'includes ActiveModel::Model' do
      expect(described_class.ancestors).to include(ActiveModel::Model)
    end

    it 'includes ActiveModel::Attributes' do
      expect(described_class.ancestors).to include(ActiveModel::Attributes)
    end

    it 'responds to ActiveModel methods' do
      expect(grouped_measure_change).to respond_to(:valid?)
      expect(grouped_measure_change).to respond_to(:errors)
    end
  end
end
