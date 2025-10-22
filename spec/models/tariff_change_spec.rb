# frozen_string_literal: true

RSpec.describe TariffChange do
  describe 'associations' do
    it { is_expected.to respond_to(:goods_nomenclature) }
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
end
