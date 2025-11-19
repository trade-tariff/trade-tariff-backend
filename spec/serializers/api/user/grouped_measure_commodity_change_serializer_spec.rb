require 'rails_helper'

RSpec.describe Api::User::GroupedMeasureCommodityChangeSerializer do
  subject(:serialized) { described_class.new(serializable, serializer_options).serializable_hash }

  let!(:commodity) { create(:goods_nomenclature, goods_nomenclature_item_id: '1234567890') }

  let(:serializable) do
    TariffChanges::GroupedMeasureCommodityChange.new(
      goods_nomenclature_item_id: '1234567890',
      count: 3,
      grouped_measure_change_id: 'import_GB_FR-DE',
    )
  end

  let(:serializer_options) { {} }

  describe '#serializable_hash' do
    it 'returns the correct structure' do
      expect(serialized[:data]).to include(
        id: 'import_GB_FR-DE_1234567890',
        type: :grouped_measure_commodity_change,
        attributes: {
          count: 3,
          impacted_measures: nil,
        },
      )
    end

    it 'has the correct id' do
      expect(serialized[:data][:id]).to eq('import_GB_FR-DE_1234567890')
    end

    it 'has the correct type' do
      expect(serialized[:data][:type]).to eq(:grouped_measure_commodity_change)
    end

    it 'has the correct attributes' do
      expect(serialized[:data][:attributes]).to eq(
        count: 3,
        impacted_measures: nil,
      )
    end

    context 'with commodity relationship included' do
      let(:serializable) do
        commodity_change = TariffChanges::GroupedMeasureCommodityChange.new(
          goods_nomenclature_item_id: '1234567890',
          count: 3,
          grouped_measure_change_id: 'import_GB_FR-DE',
        )
        commodity_change.commodity = commodity
        commodity_change
      end

      let(:serializer_options) do
        { include: %w[commodity] }
      end

      it 'includes commodity relationship' do
        expect(serialized[:data][:relationships]).to have_key(:commodity)
        expect(serialized[:data][:relationships][:commodity]).to eq(
          data: {
            id: commodity.id.to_s,
            type: :commodity,
          },
        )
      end

      it 'includes the related commodity data' do
        expect(serialized[:included]).to include(
          id: commodity.id.to_s,
          type: :commodity,
          attributes: hash_including(
            goods_nomenclature_item_id: '1234567890',
          ),
        )
      end
    end

    context 'without commodity include option' do
      let(:serializer_options) { {} }

      it 'includes relationships for commodity even without explicit include' do
        expect(serialized[:data]).to have_key(:relationships)
        expect(serialized[:data][:relationships]).to have_key(:commodity)
      end
    end

    context 'with nil count' do
      let(:serializable) do
        TariffChanges::GroupedMeasureCommodityChange.new(
          goods_nomenclature_item_id: '1234567890',
          count: nil,
          grouped_measure_change_id: 'export_US_',
        )
      end

      it 'handles nil count correctly' do
        expect(serialized[:data][:attributes]).to eq(
          count: nil,
          impacted_measures: nil,
        )
      end
    end

    context 'with zero count' do
      let(:serializable) do
        TariffChanges::GroupedMeasureCommodityChange.new(
          goods_nomenclature_item_id: '1234567890',
          count: 0,
          grouped_measure_change_id: 'both_CN_RU',
        )
      end

      it 'handles zero count correctly' do
        expect(serialized[:data][:attributes]).to eq(
          count: 0,
          impacted_measures: nil,
        )
      end
    end

    context 'with different id structure' do
      let(:serializable) do
        TariffChanges::GroupedMeasureCommodityChange.new(
          goods_nomenclature_item_id: '9876543210',
          count: 1,
          grouped_measure_change_id: 'export_US_',
        )
      end

      it 'generates correct id for different inputs' do
        expect(serialized[:data][:id]).to eq('export_US__9876543210')
      end
    end

    context 'when commodity does not exist' do
      let(:serializable) do
        TariffChanges::GroupedMeasureCommodityChange.new(
          goods_nomenclature_item_id: 'nonexistent',
          count: 5,
          grouped_measure_change_id: 'import_GB_',
        )
      end

      let(:serializer_options) do
        { include: %w[commodity] }
      end

      it 'handles non-existent commodity gracefully' do
        expect(serialized[:data][:attributes]).to eq(count: 5, impacted_measures: nil)
        expect(serialized[:data][:relationships][:commodity][:data]).to be_nil
      end
    end
  end
end
