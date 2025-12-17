# frozen_string_literal: true

RSpec.describe TariffChange do
  describe 'associations' do
    it { is_expected.to respond_to(:goods_nomenclature) }
  end

  describe '#measure' do
    context 'when type is Measure and a measure exists' do
      let(:measure) { create(:measure) }
      let(:tariff_change) { create(:tariff_change, type: 'Measure', object_sid: measure.measure_sid) }

      it 'returns the associated measure' do
        expect(tariff_change.measure.values.except(:created_at)).to eq(measure.values.except(:created_at))
      end

      it 'memoizes the result' do
        first_call = tariff_change.measure
        allow(Measure).to receive(:find)
        second_call = tariff_change.measure

        expect(Measure).not_to have_received(:find)
        expect(second_call).to eq(first_call)
      end
    end

    context 'when type is Measure but measure does not exist' do
      let(:tariff_change) { create(:tariff_change, type: 'Measure', object_sid: 999_999) }

      it 'returns nil' do
        expect(tariff_change.measure).to be_nil
      end
    end

    context 'when type is not Measure' do
      let(:tariff_change) { create(:tariff_change, type: 'Commodity', object_sid: 123) }

      it 'returns nil' do
        expect(tariff_change.measure).to be_nil
      end

      it 'does not query for a measure' do
        allow(Measure).to receive(:find)
        tariff_change.measure

        expect(Measure).not_to have_received(:find)
      end
    end
  end

  describe '.delete_for' do
    let(:operation_date) { Date.new(2025, 1, 15) }

    context 'when there are tariff changes for the given operation date' do
      let(:matching_change1) { create(:tariff_change, operation_date: operation_date) }
      let(:matching_change2) { create(:tariff_change, operation_date: operation_date) }
      let(:non_matching_change) { create(:tariff_change, operation_date: operation_date + 1.day) }

      it 'deletes all tariff changes for that date' do
        matching_change1 # ensure record exists
        matching_change2 # ensure record exists
        expect { described_class.delete_for(operation_date: operation_date) }
          .to change(described_class, :count).by(-2)
      end

      it 'does not delete tariff changes for other dates' do
        matching_change1 # ensure records exist
        matching_change2 # ensure records exist
        described_class.delete_for(operation_date: operation_date)

        expect(described_class.where(id: non_matching_change.id).first).not_to be_nil
      end

      it 'returns the number of deleted records' do
        matching_change1 # ensure records exist
        matching_change2 # ensure records exist
        result = described_class.delete_for(operation_date: operation_date)

        expect(result).to eq(2)
      end
    end

    context 'when there are no tariff changes for the given operation date' do
      it 'does not delete any records' do
        expect { described_class.delete_for(operation_date: Date.new(2025, 2, 1)) }
          .not_to change(described_class, :count)
      end

      it 'returns 0' do
        result = described_class.delete_for(operation_date: Date.new(2025, 2, 1))

        expect(result).to eq(0)
      end
    end
  end

  describe 'validations' do
    subject(:tariff_change) { build(:tariff_change) }

    it { is_expected.to be_valid }

    it 'requires object_sid' do
      expect { create(:tariff_change, object_sid: nil) }
        .to raise_error(Sequel::ValidationFailed, /object_sid is not present/)
    end

    it 'requires goods_nomenclature_sid' do
      expect { create(:tariff_change, goods_nomenclature_sid: nil) }
        .to raise_error(Sequel::ValidationFailed, /goods_nomenclature_sid is not present/)
    end

    it 'requires goods_nomenclature_item_id' do
      expect { create(:tariff_change, goods_nomenclature_item_id: nil) }
        .to raise_error(Sequel::ValidationFailed, /goods_nomenclature_item_id is not present/)
    end

    it 'requires action' do
      expect { create(:tariff_change, action: nil) }
        .to raise_error(Sequel::ValidationFailed, /action is not present/)
    end

    it 'requires operation_date' do
      expect { create(:tariff_change, operation_date: nil) }
        .to raise_error(Sequel::ValidationFailed, /operation_date is not present/)
    end

    it 'requires date_of_effect' do
      expect { create(:tariff_change, date_of_effect: nil) }
        .to raise_error(Sequel::ValidationFailed, /date_of_effect is not present/)
    end
  end

  describe '.measures' do
    let!(:measure_change1) { create(:tariff_change, type: 'Measure') }
    let!(:measure_change2) { create(:tariff_change, type: 'Measure') }
    let!(:commodity_change) { create(:tariff_change, type: 'Commodity') }
    let!(:other_change) { create(:tariff_change, type: 'SomeOtherType') }

    it 'returns only tariff changes with type Measure' do
      result = described_class.measures.all

      expect(result).to contain_exactly(measure_change1, measure_change2)
      expect(result).not_to include(commodity_change, other_change)
    end

    it 'returns an empty dataset when no measures exist' do
      described_class.where(type: 'Measure').delete

      result = described_class.measures.all

      expect(result).to be_empty
    end

    it 'can be chained with other dataset methods' do
      operation_date = Date.current
      different_date = Date.current + 1.day

      measure_change1.update(operation_date: operation_date)
      measure_change2.update(operation_date: different_date)

      result = described_class.measures.where(operation_date: operation_date).all

      expect(result).to contain_exactly(measure_change1)
      expect(result).not_to include(measure_change2)
    end
  end

  describe '.commodities' do
    let!(:commodity_change) { create(:tariff_change, type: 'Commodity') }
    let!(:measure_change) { create(:tariff_change, type: 'Measure') }

    it 'returns only tariff changes with type Commodity' do
      result = described_class.commodities.all
      expect(result).to contain_exactly(commodity_change)
      expect(result).not_to include(measure_change)
    end
  end

  describe '.commodity_descriptions' do
    let!(:description_change) { create(:tariff_change, type: 'GoodsNomenclatureDescription') }
    let!(:measure_change) { create(:tariff_change, type: 'Measure') }

    it 'returns only tariff changes with type GoodsNomenclatureDescription' do
      result = described_class.commodity_descriptions.all
      expect(result).to contain_exactly(description_change)
      expect(result).not_to include(measure_change)
    end
  end

  describe 'metadata methods' do
    describe '#measure_metadata' do
      context 'when metadata contains measure data' do
        let(:metadata) do
          {
            'measure' => {
              'measure_type_id' => '123',
              'trade_movement_code' => 1,
              'geographical_area_id' => 'GB',
              'excluded_geographical_area_ids' => %w[FR DE],
              'additional_code' => 'A123: Test code',
            },
          }
        end
        let(:tariff_change) { create(:tariff_change, metadata: metadata) }

        it 'returns the measure metadata hash' do
          expect(tariff_change.measure_metadata).to eq(metadata['measure'])
        end
      end

      context 'when metadata is nil' do
        let(:tariff_change) { create(:tariff_change, metadata: nil) }

        it 'returns empty hash' do
          expect(tariff_change.measure_metadata).to eq({})
        end
      end

      context 'when metadata does not contain measure key' do
        let(:tariff_change) { create(:tariff_change, metadata: { 'other' => 'data' }) }

        it 'returns empty hash' do
          expect(tariff_change.measure_metadata).to eq({})
        end
      end

      context 'when metadata is empty hash' do
        let(:tariff_change) { create(:tariff_change, metadata: {}) }

        it 'returns empty hash' do
          expect(tariff_change.measure_metadata).to eq({})
        end
      end
    end

    describe '#measure_type_id' do
      context 'when measure metadata contains measure_type_id' do
        let(:metadata) { { 'measure' => { 'measure_type_id' => '456' } } }
        let(:tariff_change) { create(:tariff_change, metadata: metadata) }

        it 'returns the measure type id' do
          expect(tariff_change.measure_type_id).to eq('456')
        end
      end

      context 'when measure_type_id is numeric' do
        let(:metadata) { { 'measure' => { 'measure_type_id' => 789 } } }
        let(:tariff_change) { create(:tariff_change, metadata: metadata) }

        it 'returns the numeric measure type id' do
          expect(tariff_change.measure_type_id).to eq(789)
        end
      end

      context 'when measure metadata does not contain measure_type_id' do
        let(:tariff_change) { create(:tariff_change, metadata: {}) }

        it 'returns nil' do
          expect(tariff_change.measure_type_id).to be_nil
        end
      end
    end

    describe '#trade_movement_code' do
      context 'when measure metadata contains trade_movement_code' do
        let(:metadata) { { 'measure' => { 'trade_movement_code' => 2 } } }
        let(:tariff_change) { create(:tariff_change, metadata: metadata) }

        it 'returns the trade movement code' do
          expect(tariff_change.trade_movement_code).to eq(2)
        end
      end

      context 'when trade_movement_code is zero' do
        let(:metadata) { { 'measure' => { 'trade_movement_code' => 0 } } }
        let(:tariff_change) { create(:tariff_change, metadata: metadata) }

        it 'returns zero' do
          expect(tariff_change.trade_movement_code).to eq(0)
        end
      end

      context 'when measure metadata does not contain trade_movement_code' do
        let(:tariff_change) { create(:tariff_change, metadata: {}) }

        it 'returns nil' do
          expect(tariff_change.trade_movement_code).to be_nil
        end
      end
    end

    describe '#geographical_area_id' do
      context 'when measure metadata contains geographical_area_id' do
        let(:metadata) { { 'measure' => { 'geographical_area_id' => 'US' } } }
        let(:tariff_change) { create(:tariff_change, metadata: metadata) }

        it 'returns the geographical area id' do
          expect(tariff_change.geographical_area_id).to eq('US')
        end
      end

      context 'when geographical_area_id is numeric' do
        let(:metadata) { { 'measure' => { 'geographical_area_id' => 1011 } } }
        let(:tariff_change) { create(:tariff_change, metadata: metadata) }

        it 'returns the numeric geographical area id' do
          expect(tariff_change.geographical_area_id).to eq(1011)
        end
      end

      context 'when measure metadata does not contain geographical_area_id' do
        let(:tariff_change) { create(:tariff_change, metadata: {}) }

        it 'returns nil' do
          expect(tariff_change.geographical_area_id).to be_nil
        end
      end
    end

    describe '#excluded_geographical_area_ids' do
      context 'when measure metadata contains excluded_geographical_area_ids' do
        let(:metadata) { { 'measure' => { 'excluded_geographical_area_ids' => %w[CN IN] } } }
        let(:tariff_change) { create(:tariff_change, metadata: metadata) }

        it 'returns the excluded geographical area ids' do
          expect(tariff_change.excluded_geographical_area_ids).to eq(%w[CN IN])
        end
      end

      context 'when excluded_geographical_area_ids contains numeric values' do
        let(:metadata) { { 'measure' => { 'excluded_geographical_area_ids' => [1001, 1002] } } }
        let(:tariff_change) { create(:tariff_change, metadata: metadata) }

        it 'returns the numeric excluded geographical area ids' do
          expect(tariff_change.excluded_geographical_area_ids).to eq([1001, 1002])
        end
      end

      context 'when excluded_geographical_area_ids is empty array' do
        let(:metadata) { { 'measure' => { 'excluded_geographical_area_ids' => [] } } }
        let(:tariff_change) { create(:tariff_change, metadata: metadata) }

        it 'returns empty array' do
          expect(tariff_change.excluded_geographical_area_ids).to eq([])
        end
      end

      context 'when measure metadata does not contain excluded_geographical_area_ids' do
        let(:tariff_change) { create(:tariff_change, metadata: {}) }

        it 'returns empty array' do
          expect(tariff_change.excluded_geographical_area_ids).to eq([])
        end
      end

      context 'when excluded_geographical_area_ids is nil in metadata' do
        let(:metadata) { { 'measure' => { 'excluded_geographical_area_ids' => nil } } }
        let(:tariff_change) { create(:tariff_change, metadata: metadata) }

        it 'returns empty array' do
          expect(tariff_change.excluded_geographical_area_ids).to eq([])
        end
      end
    end

    describe '#additional_code' do
      context 'when measure metadata contains additional_code' do
        let(:metadata) { { 'measure' => { 'additional_code' => 'B456: Special code' } } }
        let(:tariff_change) { create(:tariff_change, metadata: metadata) }

        it 'returns the additional code' do
          expect(tariff_change.additional_code).to eq('B456: Special code')
        end
      end

      context 'when measure metadata does not contain additional_code' do
        let(:tariff_change) { create(:tariff_change, metadata: {}) }

        it 'returns nil' do
          expect(tariff_change.additional_code).to be_nil
        end
      end

      context 'when additional_code is empty string in metadata' do
        let(:metadata) { { 'measure' => { 'additional_code' => '' } } }
        let(:tariff_change) { create(:tariff_change, metadata: metadata) }

        it 'returns empty string' do
          expect(tariff_change.additional_code).to eq('')
        end
      end
    end

    describe 'metadata method integration' do
      context 'with a fully populated metadata object' do
        let(:metadata) do
          {
            'measure' => {
              'measure_type_id' => '103',
              'trade_movement_code' => 1,
              'geographical_area_id' => 'GB',
              'excluded_geographical_area_ids' => %w[FR DE IT],
              'additional_code' => 'X123: Export restriction',
            },
          }
        end
        let(:tariff_change) { create(:tariff_change, type: 'Measure', metadata: metadata) }

        it 'all metadata methods work together correctly' do
          expect(tariff_change.measure_type_id).to eq('103')
          expect(tariff_change.trade_movement_code).to eq(1)
          expect(tariff_change.geographical_area_id).to eq('GB')
          expect(tariff_change.excluded_geographical_area_ids).to eq(%w[FR DE IT])
          expect(tariff_change.additional_code).to eq('X123: Export restriction')
        end
      end

      context 'with a non-measure type tariff change' do
        let(:tariff_change) { create(:tariff_change, type: 'Commodity', metadata: {}) }

        it 'metadata methods still work correctly' do
          expect(tariff_change.measure_type_id).to be_nil
          expect(tariff_change.trade_movement_code).to be_nil
          expect(tariff_change.geographical_area_id).to be_nil
          expect(tariff_change.excluded_geographical_area_ids).to eq([])
          expect(tariff_change.additional_code).to be_nil
        end
      end
    end
  end

  describe '#description' do
    let(:tariff_change) { described_class.new(type: 'Commodity', action: action) }

    context 'when action is CREATION' do
      let(:action) { TariffChangesService::BaseChanges::CREATION }

      it 'returns begin description' do
        expect(tariff_change.description).to eq('Commodity will begin')
      end
    end

    context 'when action is ENDING' do
      let(:action) { TariffChangesService::BaseChanges::ENDING }

      it 'returns end description' do
        expect(tariff_change.description).to eq('Commodity will end')
      end
    end

    context 'when action is UPDATE' do
      let(:action) { TariffChangesService::BaseChanges::UPDATE }

      it 'returns update description' do
        expect(tariff_change.description).to eq('Commodity will be updated')
      end
    end

    context 'when action is DELETION' do
      let(:action) { TariffChangesService::BaseChanges::DELETION }

      it 'returns delete description' do
        expect(tariff_change.description).to eq('Commodity will be deleted')
      end
    end
  end
end
