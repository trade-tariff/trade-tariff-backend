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
        allow(GeographicalArea).to receive(:where).and_call_original
        2.times { grouped_measure_change.excluded_geographical_areas }
        expect(GeographicalArea).to have_received(:where).once
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
