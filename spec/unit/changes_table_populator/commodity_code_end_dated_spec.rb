require 'rails_helper'

describe ChangesTablePopulator::CommodityCodeEndDated do
  let(:db) { Sequel::Model.db }

  describe '#populate' do
    context 'when the database is empty' do
      before do
        db[:goods_nomenclatures].delete
      end

      it 'doesn\'t extract changes' do
        expect { described_class.populate }.not_to change(Change, :count)
      end
    end

    context 'when there are commodities but haven\'t changed' do
      before do
        create :goods_nomenclature
      end

      it 'doesn\'t extract changes' do
        expect { described_class.populate }.not_to change(Change, :count)
      end
    end

    context 'when there are commodities that ended on the previous day' do
      before do
        create :goods_nomenclature, validity_end_date: Date.current - 1.day
      end

      it 'extracts changes' do
        expect { described_class.populate }.to change(Change, :count).by(1)
      end

      it 'will extract the correct productline suffix' do
        described_class.populate
        expect(db[:changes].first[:productline_suffix]).to eq('80')
      end

      it 'will flag it as end line' do
        described_class.populate
        expect(db[:changes].first[:end_line]).to be true
      end
    end

    context 'when there are commodities with children that ended on the previous day' do
      before do
        commodity = create :commodity, :with_heading

        heading = commodity.heading
        heading.validity_end_date = Date.current - 1.day
        heading.save
      end

      it 'extracts a change' do
        expect { described_class.populate }.to change(Change, :count).by(1)
      end

      it 'will extract the correct productline suffix' do
        described_class.populate
        expect(db[:changes].first[:productline_suffix]).to eq('80')
      end

      it 'will flag it as not end line' do
        described_class.populate
        expect(db[:changes].first[:end_line]).to be false
      end
    end
  end
end
