RSpec.describe ChangesTablePopulator::CommodityCodeStarted do
  let(:db) { Sequel::Model.db }

  describe '#populate' do
    # rubocop:disable RSpec::EmptyExampleGroup
    context 'when the database is empty' do
      before do
        db[:goods_nomenclatures_oplog].delete
      end

      it_with_refresh_materialized_view 'doesn\'t extract changes' do
        expect { described_class.populate }.not_to change(Change, :count)
      end
    end
    # rubocop:enable RSpec::EmptyExampleGroup

    context 'when there are commodities but haven\'t changed' do
      before do
        create :goods_nomenclature
      end

      it 'doesn\'t extract changes' do
        expect { described_class.populate }.not_to change(Change, :count)
      end
    end

    context 'when there are commodities that started on the same day' do
      before do
        create :goods_nomenclature, validity_start_date: Time.zone.today
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

    # rubocop:disable RSpec::EmptyExampleGroup
    context 'when there are commodities with children that started on the same day' do
      before do
        commodity = create :commodity, :with_heading

        heading = commodity.heading
        heading.validity_start_date = Time.zone.today
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
