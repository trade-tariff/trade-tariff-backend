RSpec.describe ChangesTablePopulator::MeasureDeleted do
  let(:db) { Sequel::Model.db }

  describe '#populate' do
    context 'when the database is empty' do
      before do
        db[:measures].delete
      end

      it 'doesn\'t extract changes' do
        expect { described_class.populate }.not_to change(Change, :count)
      end
    end

    context 'when there are measures but haven\'t changed' do
      before do
        create :measure
      end

      it 'doesn\'t extract changes' do
        expect { described_class.populate }.not_to change(Change, :count)
      end
    end

    context 'when a measure has been deleted on the same day' do
      before do
        measure = create :measure

        db.run("UPDATE measures_oplog SET operation = 'D', operation_date = '#{Date.current}' " \
               "WHERE measure_sid = '#{measure.measure_sid}'")
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

    context 'when the measure is associated to a commodity with children' do
      before do
        commodity = create :commodity, :with_heading, :with_children
        measure = create :measure,
                         goods_nomenclature_item_id: commodity.goods_nomenclature_item_id,
                         goods_nomenclature_sid: commodity.goods_nomenclature_sid,
                         goods_nomenclature: commodity

        db.run("UPDATE measures_oplog SET operation = 'D', operation_date = '#{Date.current}' " \
               "WHERE measure_sid = '#{measure.measure_sid}'")
      end

      it 'extracts the commodity and the child commodity as change' do
        expect { described_class.populate }.to change(Change, :count).by(4)
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

    context 'when the measure is associated to a heading with children' do
      before do
        commodity = create :commodity, :with_heading, :with_children
        heading = commodity.heading
        measure = create :measure,
                         goods_nomenclature_item_id: heading.goods_nomenclature_item_id,
                         goods_nomenclature_sid: heading.goods_nomenclature_sid,
                         goods_nomenclature: heading

        db.run("UPDATE measures_oplog SET operation = 'D', operation_date = '#{Date.current}' " \
               "WHERE measure_sid = '#{measure.measure_sid}'")
      end

      it 'extracts the commodity and the child commodity as change' do
        expect { described_class.populate }.to change(Change, :count).by(5)
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
