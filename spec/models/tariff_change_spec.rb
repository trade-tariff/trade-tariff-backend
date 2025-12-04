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
        expect(tariff_change.measure).to eq(measure)
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
