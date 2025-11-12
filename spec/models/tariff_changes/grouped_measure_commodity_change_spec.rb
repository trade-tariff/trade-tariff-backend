require 'rails_helper'

RSpec.describe TariffChanges::GroupedMeasureCommodityChange do
  subject(:grouped_commodity_change) do
    described_class.new(
      goods_nomenclature_item_id: '1234567890',
      count: 5,
      grouped_measure_change_id: 'import_GB_FR-DE',
    )
  end

  describe 'attributes' do
    it 'has the expected attributes' do
      expect(grouped_commodity_change.goods_nomenclature_item_id).to eq('1234567890')
      expect(grouped_commodity_change.count).to eq(5)
      expect(grouped_commodity_change.grouped_measure_change_id).to eq('import_GB_FR-DE')
    end

    it 'can be initialized with minimal attributes' do
      minimal_change = described_class.new(goods_nomenclature_item_id: '9876543210')
      expect(minimal_change.goods_nomenclature_item_id).to eq('9876543210')
      expect(minimal_change.count).to be_nil
      expect(minimal_change.grouped_measure_change_id).to be_nil
    end
  end

  describe '#id' do
    it 'generates correct id from attributes' do
      expect(grouped_commodity_change.id).to eq('import_GB_FR-DE_1234567890')
    end

    context 'when grouped_measure_change_id is nil' do
      subject(:grouped_commodity_change) do
        described_class.new(
          goods_nomenclature_item_id: '1234567890',
          grouped_measure_change_id: nil,
        )
      end

      it 'generates id with nil prefix' do
        expect(grouped_commodity_change.id).to eq('_1234567890')
      end
    end

    context 'when goods_nomenclature_item_id is nil' do
      subject(:grouped_commodity_change) do
        described_class.new(
          goods_nomenclature_item_id: nil,
          grouped_measure_change_id: 'export_US_',
        )
      end

      it 'generates id with nil suffix' do
        expect(grouped_commodity_change.id).to eq('export_US__')
      end
    end
  end

  describe '#commodity' do
    context 'when goods nomenclature exists' do
      let(:goods_nomenclature) { create(:goods_nomenclature, goods_nomenclature_item_id: '1234567890') }

      it 'returns the corresponding Commodity' do
        goods_nomenclature # Ensure it's created
        expect(grouped_commodity_change.commodity).to be_a(Commodity)
        expect(grouped_commodity_change.commodity.goods_nomenclature_item_id).to eq('1234567890')
      end

      it 'memoizes the result' do
        goods_nomenclature # Ensure it's created
        allow(GoodsNomenclature).to receive(:find).and_call_original

        2.times { grouped_commodity_change.commodity }

        expect(GoodsNomenclature).to have_received(:find).once
      end
    end

    context 'when goods nomenclature does not exist' do
      it 'returns nil for non-existent commodity' do
        expect(grouped_commodity_change.commodity).to be_nil
      end
    end

    context 'when goods_nomenclature_item_id is nil' do
      subject(:grouped_commodity_change) do
        described_class.new(goods_nomenclature_item_id: nil)
      end

      it 'returns nil when goods_nomenclature_item_id is nil' do
        expect(grouped_commodity_change.commodity).to be_nil
      end
    end

    context 'when goods_nomenclature_item_id is blank' do
      subject(:grouped_commodity_change) do
        described_class.new(goods_nomenclature_item_id: '')
      end

      it 'returns nil when goods_nomenclature_item_id is blank' do
        expect(grouped_commodity_change.commodity).to be_nil
      end
    end
  end

  describe '#grouped_measure_change' do
    context 'when grouped_measure_change_id is present' do
      it 'returns a GroupedMeasureChange object created from the id' do
        result = grouped_commodity_change.grouped_measure_change

        expect(result).to be_a(TariffChanges::GroupedMeasureChange)
        expect(result.trade_direction).to eq('import')
        expect(result.geographical_area_id).to eq('GB')
        expect(result.excluded_geographical_area_ids).to eq(%w[FR DE])
      end

      it 'memoizes the result' do
        allow(TariffChanges::GroupedMeasureChange).to receive(:from_id).and_call_original

        2.times { grouped_commodity_change.grouped_measure_change }

        expect(TariffChanges::GroupedMeasureChange).to have_received(:from_id).once
      end
    end

    context 'when grouped_measure_change_id is nil' do
      subject(:grouped_commodity_change) do
        described_class.new(
          goods_nomenclature_item_id: '1234567890',
          grouped_measure_change_id: nil,
        )
      end

      it 'returns nil' do
        expect(grouped_commodity_change.grouped_measure_change).to be_nil
      end
    end

    context 'when grouped_measure_change_id is blank' do
      subject(:grouped_commodity_change) do
        described_class.new(
          goods_nomenclature_item_id: '1234567890',
          grouped_measure_change_id: '',
        )
      end

      it 'returns a GroupedMeasureChange with empty parts' do
        result = grouped_commodity_change.grouped_measure_change

        expect(result).to be_a(TariffChanges::GroupedMeasureChange)
        expect(result.trade_direction).to be_nil
        expect(result.geographical_area_id).to be_nil
        expect(result.excluded_geographical_area_ids).to eq([])
      end
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
      expect(grouped_commodity_change).to respond_to(:valid?)
      expect(grouped_commodity_change).to respond_to(:errors)
    end

    it 'can be validated' do
      expect(grouped_commodity_change.valid?).to be true
      expect(grouped_commodity_change.errors).to be_empty
    end
  end

  describe 'associations' do
    it 'establishes the bidirectional relationship correctly' do
      # Create a grouped measure change and add a commodity change
      grouped_measure_change = TariffChanges::GroupedMeasureChange.new(
        trade_direction: 'import',
        geographical_area_id: 'GB',
        excluded_geographical_area_ids: %w[FR DE],
      )

      commodity_change = grouped_measure_change.add_commodity_change(
        goods_nomenclature_item_id: '1234567890',
        count: 3,
      )

      # Test the bidirectional relationship
      expect(commodity_change.grouped_measure_change_id).to eq(grouped_measure_change.id)
      expect(commodity_change.grouped_measure_change).to be_a(TariffChanges::GroupedMeasureChange)
      expect(commodity_change.grouped_measure_change.trade_direction).to eq('import')
    end
  end
end
