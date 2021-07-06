require 'rails_helper'

describe ChangesTablePopulator::MeasureStarted do
  let(:db) { Sequel::Model.db }

  describe '#perform_import' do
    context 'when the database is empty' do
      before do
        db[:measures].delete
      end

      it 'doesn\'t extract changes' do
        expect { described_class.perform_import }.not_to change(Change, :count)
      end
    end

    context 'when there are measures but haven\'t changed' do
      before do
        create :measure
      end

      it 'doesn\'t extract changes' do
        expect { described_class.perform_import }.not_to change(Change, :count)
      end
    end

    context 'when there are measures that started on the same day' do
      before do
        create :measure, validity_start_date: Date.current
      end

      it 'extracts changes' do
        expect { described_class.perform_import }.to change(Change, :count).by(1)
      end

      it 'will extract the correct productline suffix' do
        described_class.perform_import
        expect(db[:changes].first[:productline_suffix]).to eq('80')
      end

      it 'will flag it as end line' do
        described_class.perform_import
        expect(db[:changes].first[:end_line]).to be true
      end
    end

    context 'when the measure is associated to a commodity with children' do
      before do
        commodity = create :commodity, :with_heading, :with_children
        create :measure,
               goods_nomenclature_item_id: commodity.goods_nomenclature_item_id,
               goods_nomenclature_sid: commodity.goods_nomenclature_sid,
               goods_nomenclature: commodity,
               validity_start_date: Date.current
      end

      it 'extracts the commodity and the child commodity as change' do
        expect { described_class.perform_import }.to change(Change, :count).by(4)
      end

      it 'will extract the correct productline suffix' do
        described_class.perform_import
        expect(db[:changes].first[:productline_suffix]).to eq('80')
      end

      it 'will flag it as not end line' do
        described_class.perform_import
        expect(db[:changes].first[:end_line]).to be false
      end
    end

    context 'when the measure is associated to a heading with children' do
      before do
        commodity = create :commodity, :with_heading, :with_children
        heading = commodity.heading
        create :measure,
               goods_nomenclature_item_id: heading.goods_nomenclature_item_id,
               goods_nomenclature_sid: heading.goods_nomenclature_sid,
               goods_nomenclature: heading,
               validity_start_date: Date.current
      end

      it 'extracts the commodity and the child commodity as change' do
        expect { described_class.perform_import }.to change(Change, :count).by(5)
      end

      it 'will extract the correct productline suffix' do
        described_class.perform_import
        expect(db[:changes].first[:productline_suffix]).to eq('80')
      end

      it 'will flag it as not end line' do
        described_class.perform_import
        expect(db[:changes].first[:end_line]).to be false
      end
    end
  end
end
