RSpec.describe ChangesTablePopulator::CommodityCodeEndDated do
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
        create :goods_nomenclature
      end

      it 'doesn\'t extract changes' do
        expect { described_class.populate }.not_to change(Change, :count)
      end
    end

    context 'when there are taric commodities that ended on the previous day' do
      before do
        create :goods_nomenclature, validity_end_date: taric_end_date
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

    context 'when there are cds commodities that ended on the previous day' do
      before do
        create :goods_nomenclature, validity_end_date: cds_end_date
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

    # rubocop:disable RSpec::EmptyExampleGroup
    context 'when there are commodities with children that ended on the previous day' do
      before do
        commodity = create :commodity, :with_heading

        heading = commodity.heading
        heading.validity_end_date = Time.zone.today - 1.day
        heading.save
      end

      it_with_refresh_materialized_view 'extracts a change' do
        expect { described_class.populate }.to change(Change, :count).by(1)
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
    # rubocop:enable RSpec::EmptyExampleGroup
  end
end
