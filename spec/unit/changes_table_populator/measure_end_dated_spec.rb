RSpec.describe ChangesTablePopulator::MeasureEndDated do
  let(:db) { Sequel::Model.db }

  describe '#populate' do
    context 'when there are measures but haven\'t changed' do
      before do
        create :measure, :with_goods_nomenclature
      end

      it 'doesn\'t extract changes' do
        expect { described_class.populate }.not_to change(Change, :count)
      end
    end

    context 'when there are measures that ended on the previous day in Taric' do
      before do
        create :measure, :with_goods_nomenclature, validity_end_date: taric_end_date
      end

      let(:taric_end_date) { 1.day.ago.beginning_of_day }

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

    context 'when there are measures that ended on the previous day in CDS' do
      before do
        create :measure, :with_goods_nomenclature, validity_end_date: cds_end_date
      end

      let(:cds_end_date) { 1.day.ago.end_of_day }

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

    context 'when the measure is associated to a commodity with children' do
      before do
        commodity = create :commodity, :with_heading, :with_children
        create :measure,
               goods_nomenclature_item_id: commodity.goods_nomenclature_item_id,
               goods_nomenclature_sid: commodity.goods_nomenclature_sid,
               goods_nomenclature: commodity,
               validity_end_date: Time.zone.today - 1.day
      end

      it 'extracts the commodity and the child commodity as change' do
        expect { described_class.populate }.to change(Change, :count).by(4)
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

    context 'when the measure is associated to a heading with children' do
      before do
        commodity = create :commodity, :with_heading, :with_children
        heading = commodity.heading
        create :measure,
               goods_nomenclature_item_id: heading.goods_nomenclature_item_id,
               goods_nomenclature_sid: heading.goods_nomenclature_sid,
               goods_nomenclature: heading,
               validity_end_date: Time.zone.today - 1.day
      end

      it 'extracts the commodity and the child commodity as change' do
        expect { described_class.populate }.to change(Change, :count).by(5)
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

    context 'when the measure is associated to a goods_nomenclature which is end dated on the same day' do
      before { measure }

      let(:yesterday) { Time.zone.today - 1.day }
      let(:commodity) { create :commodity, :with_heading, :with_children, validity_end_date: yesterday }
      let(:measure) { create :measure, goods_nomenclature: commodity, validity_end_date: yesterday }

      it 'extracts the commodity and the child commodity as change' do
        expect { described_class.populate }.to change(Change, :count).by(4)
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
