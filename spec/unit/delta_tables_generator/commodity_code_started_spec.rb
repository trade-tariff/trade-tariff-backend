require 'rails_helper'

describe DeltaTablesGenerator::CommodityCodeStarted do
  let(:db) { Sequel::Model.db }

  describe '#perform_import' do
    context 'when the database is empty' do
      before do
        db[:goods_nomenclatures].delete
      end

      it 'doesn\'t extract deltas' do
        expect { described_class.perform_import }.not_to change{ Delta.count }
      end
    end

    context 'when there are commodities but haven\'t changed' do
      let!(:commodity) { create :goods_nomenclature }

      it 'doesn\'t extract deltas' do
        expect { described_class.perform_import }.not_to change{ Delta.count }
      end
    end

    context 'when there are commodities that started on the same day' do
      let!(:commodity) { create :goods_nomenclature, validity_start_date: Date.current }

      it 'extracts deltas' do
        expect { described_class.perform_import }.to change{ Delta.count }.by(1)
      end

      it 'will extract the correct productline suffix' do
        described_class.perform_import
        expect(db[:deltas].first.dig(:productline_suffix)).to eq('80')
      end

      it 'will flag it as end line' do
        described_class.perform_import
        expect(db[:deltas].first.dig(:end_line)).to be true
      end
    end

    context 'when there are commodities with children that started on the same day' do
      let!(:commodity) { create :commodity, :with_heading }
      before do
        heading = commodity.heading
        heading.validity_start_date = Date.current
        heading.save
      end

      it 'extracts a delta' do
        expect { described_class.perform_import }.to change{ Delta.count }.by(1)
      end

      it 'will extract the correct productline suffix' do
        described_class.perform_import
        expect(db[:deltas].first.dig(:productline_suffix)).to eq('80')
      end

      it 'will flag it as not end line' do
        described_class.perform_import
        expect(db[:deltas].first.dig(:end_line)).to be false
      end
    end
  end
end
