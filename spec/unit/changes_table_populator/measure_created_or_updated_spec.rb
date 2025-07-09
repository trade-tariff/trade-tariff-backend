RSpec.describe ChangesTablePopulator::MeasureCreatedOrUpdated do
  let(:db) { Sequel::Model.db }

  describe '#populate' do
    context 'when the database is empty' do
      before do
        db[:measures_oplog].delete
      end

      it 'doesn\'t extract changes' do
        expect { described_class.populate }.not_to change(Change, :count)
      end
    end

    context 'when there are measures created today' do
      before do
        measure = create :measure, :with_goods_nomenclature

        db.run("UPDATE measures_oplog SET operation = 'C', operation_date = '#{Time.zone.today}' " \
                 "WHERE measure_sid = '#{measure.measure_sid}'")
      end

      it_with_refresh_materialized_view 'extracts changes' do
        expect { described_class.populate }.to change(Change, :count).by(1)
      end

      it_with_refresh_materialized_view 'extracts the correct productline suffix' do
        described_class.populate
        expect(db[:changes].first[:productline_suffix]).to eq('80')
      end

      it_with_refresh_materialized_view 'flags it as end line' do
        described_class.populate
        expect(db[:changes].first[:end_line]).to be true
      end
    end

    context 'when there are measures that have been changed' do
      before do
        measure = create :measure, :with_goods_nomenclature

        db.run("UPDATE measures_oplog SET operation = 'U', operation_date = '#{Time.zone.today}' " \
                 "WHERE measure_sid = '#{measure.measure_sid}'")
      end

      it_with_refresh_materialized_view 'extracts changes' do
        expect { described_class.populate }.to change(Change, :count).by(1)
      end

      it_with_refresh_materialized_view 'extracts the correct productline suffix' do
        described_class.populate
        expect(db[:changes].first[:productline_suffix]).to eq('80')
      end

      it_with_refresh_materialized_view 'flags it as end line' do
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

        db.run("UPDATE measures_oplog SET operation = 'U', operation_date = '#{Time.zone.today}' " \
                 "WHERE measure_sid = '#{measure.measure_sid}'")
      end

      it_with_refresh_materialized_view 'extracts the commodity and the child commodity as change' do
        expect { described_class.populate }.to change(Change, :count).by(4)
      end

      it_with_refresh_materialized_view 'extracts the correct productline suffix' do
        described_class.populate
        expect(db[:changes].first[:productline_suffix]).to eq('80')
      end

      it_with_refresh_materialized_view 'flags it as not end line' do
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

        db.run("UPDATE measures_oplog SET operation = 'U', operation_date = '#{Time.zone.today}' " \
                 "WHERE measure_sid = '#{measure.measure_sid}'")
      end

      it_with_refresh_materialized_view 'extracts the commodity and the child commodity as change' do
        expect { described_class.populate }.to change(Change, :count).by(5)
      end

      it_with_refresh_materialized_view 'extracts the correct productline suffix' do
        described_class.populate
        expect(db[:changes].first[:productline_suffix]).to eq('80')
      end

      it_with_refresh_materialized_view 'flags it as not end line' do
        described_class.populate
        expect(db[:changes].first[:end_line]).to be false
      end
    end
  end
end
