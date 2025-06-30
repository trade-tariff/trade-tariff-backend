RSpec.describe ChangesTablePopulator::MeasureStarted do
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

    context 'when there are measures that started on the same day' do
      before do
        create :measure, :with_goods_nomenclature, validity_start_date: Time.zone.today
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

    context 'when the measure is associated to a commodity with children' do
      before do
        commodity = create :commodity, :with_heading, :with_children
        create :measure,
               goods_nomenclature_item_id: commodity.goods_nomenclature_item_id,
               goods_nomenclature_sid: commodity.goods_nomenclature_sid,
               goods_nomenclature: commodity,
               validity_start_date: Time.zone.today
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
      before { measure }

      let(:commodity) { create :commodity, :with_heading, :with_children }

      let :measure do
        create :measure, goods_nomenclature: commodity.heading,
                         validity_start_date: Time.zone.today
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

      context 'when childs gn item id has been reused' do
        subject(:changed_gn_sids) { Change.all.map(&:goods_nomenclature_sid) }

        before do
          historic

          described_class.populate
        end

        let :historic do
          create :commodity,
                 parent: commodity.heading,
                 goods_nomenclature_item_id: commodity.goods_nomenclature_item_id,
                 validity_start_date: 10.years.ago.beginning_of_day,
                 validity_end_date: 9.years.ago.beginning_of_day
        end

        it 'does not include the historic child' do
          expect(changed_gn_sids).not_to include historic.goods_nomenclature_sid
        end
      end
    end
  end
end
