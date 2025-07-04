RSpec.describe ChangesTablePopulator::CommodityCodeDescriptionChanged do
  let(:db) { Sequel::Model.db }

  describe '#populate' do
    context 'when the database is empty' do
      before do
        db[:goods_nomenclatures_oplog].delete
      end

      it 'doesn\'t extract changes' do
        expect { described_class.populate }.not_to change(Change, :count)
      end
    end

    context 'when there are commodities but haven\'t changed' do
      before do
        create :goods_nomenclature, :with_description
      end

      it 'doesn\'t extract changes' do
        expect { described_class.populate }.not_to change(Change, :count)
      end
    end

    context 'when there are commodities that started on the same day' do
      before do
        commodity = create :goods_nomenclature, :with_description

        period = commodity.goods_nomenclature_description.goods_nomenclature_description_period
        period.validity_start_date = Time.zone.today
        period.save
      end

      it 'extracts changes' do
        expect { described_class.populate }.to change(Change, :count).by(1)
      end

      it 'extracts the correct productline suffix' do
        described_class.populate
        expect(db[:changes].first[:productline_suffix]).to eq('80')
      end

      it 'flags it as end line' do
        described_class.populate
        expect(db[:changes].first[:end_line]).to be true
      end
    end

    context 'when the commodity is a header with a current commodity' do
      before do
        commodity = create :commodity, :with_description, :with_heading
        heading = commodity.reload.heading
        create(:goods_nomenclature_description,
               goods_nomenclature_sid: heading.goods_nomenclature_sid,
               goods_nomenclature_item_id: heading.goods_nomenclature_item_id,
               validity_start_date: Time.zone.today,
               validity_end_date: heading.validity_end_date,
               description: 'Description')
      end

      it 'extracts a change' do
        expect { described_class.populate }.to change(Change, :count).by(1)
      end

      it 'extracts the correct productline suffix' do
        described_class.populate
        expect(db[:changes].first[:productline_suffix]).to eq('80')
      end

      it 'flags it as not end line' do
        described_class.populate
        expect(db[:changes].first[:end_line]).to be false
      end
    end

    context 'when the commodity has children' do
      before do
        commodity = create :commodity, :with_description, :with_heading
        heading = commodity.heading
        create(:goods_nomenclature_description,
               goods_nomenclature_sid: heading.goods_nomenclature_sid,
               goods_nomenclature_item_id: heading.goods_nomenclature_item_id,
               validity_start_date: Time.zone.today,
               validity_end_date: heading.validity_end_date,
               description: 'Description')
      end

      it 'extracts a change' do
        expect { described_class.populate }.to change(Change, :count).by(1)
      end

      it 'extracts the correct productline suffix' do
        described_class.populate
        expect(db[:changes].first[:productline_suffix]).to eq('80')
      end

      it 'flags it as not end line' do
        described_class.populate
        expect(db[:changes].first[:end_line]).to be false
      end
    end
  end
end
