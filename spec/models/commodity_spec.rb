RSpec.describe Commodity do
  before do
    TradeTariffRequest.time_machine_now = Time.current
  end

  it { expect(described_class.primary_key).to eq :goods_nomenclature_sid }

  describe 'associations' do
    describe '#heading' do
      let!(:gono1) do
        create :commodity, validity_start_date: Date.new(1999, 1, 1),
                           validity_end_date: Date.new(2013, 1, 1)
      end
      let!(:heading1) do
        create :heading, goods_nomenclature_item_id: "#{gono1.goods_nomenclature_item_id.first(4)}000000",
                         validity_start_date: Date.new(1991, 1, 1),
                         validity_end_date: Date.new(2002, 1, 1),
                         producline_suffix: '80'
      end

      before do
        create :commodity, goods_nomenclature_item_id: gono1.goods_nomenclature_item_id,
                           validity_start_date: Date.new(2005, 1, 1),
                           validity_end_date: Date.new(2013, 1, 1)
        create :heading, goods_nomenclature_item_id: "#{gono1.goods_nomenclature_item_id.first(4)}000000",
                         validity_start_date: Date.new(2002, 1, 1),
                         validity_end_date: Date.new(2014, 1, 1),
                         producline_suffix: '80'
      end

      context 'when fetching a chapter on a given day' do
        it 'fetches correct chapter' do
          TimeMachine.at('2000-1-1') do
            expect(gono1.reload.heading.pk).to eq heading1.pk
          end
        end
      end

      context 'when grouping heading and non-grouping headings' do
        before do
          create :heading, goods_nomenclature_item_id: '6308000000',
                           goods_nomenclature_sid: 43_837,
                           producline_suffix: '10',
                           validity_start_date: Date.new(1972, 1, 1)
          create :heading, goods_nomenclature_item_id: '6308000000',
                           goods_nomenclature_sid: 43_838,
                           producline_suffix: '80',
                           validity_start_date: Date.new(1972, 1, 1)
        end

        let!(:commodity) do
          create :commodity, :with_indent,
                 :with_description,
                 indents: 1,
                 goods_nomenclature_sid: 91_335,
                 goods_nomenclature_item_id: '6308000015',
                 producline_suffix: '80',
                 validity_start_date: Date.new(2009, 7, 1)
        end

        it 'correctly identifies heading' do
          expect(commodity.heading.goods_nomenclature_sid).to eq 43_838
        end
      end
    end

    describe '#chapter' do
      before do
        create :heading, goods_nomenclature_item_id: gono1.goods_nomenclature_item_id,
                         validity_start_date: Date.new(2005, 1, 1),
                         validity_end_date: Date.new(2013, 1, 1)
      end

      let!(:gono1) do
        create :heading, validity_start_date: Date.new(1999, 1, 1),
                         validity_end_date: Date.new(2013, 1, 1)
      end
      let!(:chapter1) do
        create :chapter, goods_nomenclature_item_id: "#{gono1.goods_nomenclature_item_id.first(2)}00000000",
                         validity_start_date: Date.new(1991, 1, 1),
                         validity_end_date: Date.new(2002, 1, 1)
      end

      context 'when fetching actual' do
        it 'fetches correct chapter' do
          TimeMachine.at('2000-1-1') do
            expect(gono1.reload.chapter.pk).to eq chapter1.pk
          end
        end
      end
    end
  end

  describe '#to_param' do
    let(:commodity) { create :commodity }

    it 'uses goods_nomenclature_item_id as param' do
      expect(commodity.to_param).to eq commodity.goods_nomenclature_item_id
    end
  end

  describe '.actual' do
    let!(:actual_commodity)  { create :commodity, :actual }
    let!(:expired_commodity) { create :commodity, :expired }

    context 'when not in TimeMachine block' do
      it { expect(described_class.actual).to include actual_commodity }
      it { expect(described_class.actual).not_to include expired_commodity }
    end

    context 'when in TimeMachine block' do
      before do
        TradeTariffRequest.time_machine_now = 2.years.ago.beginning_of_day
      end

      it { expect(described_class.actual).to include actual_commodity }
      it { expect(described_class.actual).to include expired_commodity }
    end
  end

  describe '#changes' do
    let(:commodity) { create :commodity }

    it 'returns Sequel Dataset' do
      expect(commodity.changes).to be_a Sequel::Dataset
    end

    context 'with commodity changes' do
      let!(:commodity) { create :commodity, operation_date: Time.zone.today }

      it 'includes commodity changes' do
        expect(
          commodity.changes.select do |change|
            change.oid == commodity.oid &&
            change.model == GoodsNomenclature
          end,
        ).to be_present
      end
    end

    context 'with associated measure changes' do
      let!(:commodity) { create :commodity, operation_date: Time.zone.yesterday }
      let!(:measure)   do
        create :measure,
               goods_nomenclature: commodity,
               goods_nomenclature_item_id: commodity.goods_nomenclature_item_id,
               operation_date: Time.zone.today
      end

      it 'includes measure changes' do
        expect(
          commodity.changes.select do |change|
            change.oid == measure.oid &&
            change.model == Measure
          end,
        ).to be_present
      end
    end
  end

  describe '.by_code' do
    let(:commodity1) { create(:commodity, goods_nomenclature_item_id: '123') }
    let(:commodity2) { create(:commodity, goods_nomenclature_item_id: '456') }

    it { expect(described_class.by_code('123')).to include(commodity1) }
    it { expect(described_class.by_code('123')).not_to include(commodity2) }
  end

  describe '.by_productline_suffix' do
    subject(:result) { described_class.by_productline_suffix('10').all }

    before do
      declarable_commodity
      non_declarable_commodity
    end

    let(:declarable_commodity) { create(:commodity, producline_suffix: '80') }
    let(:non_declarable_commodity) { create(:commodity, producline_suffix: '10') }

    it { expect(result).to eq([non_declarable_commodity]) }
  end

  describe '#goods_nomenclature_class' do
    context 'when the Commodity is declarable' do
      subject(:goods_nomenclature_class) { create(:commodity, :declarable, :with_heading).goods_nomenclature_class }

      it { is_expected.to eq('Commodity') }
    end

    context 'when the Commodity is not declarable' do
      subject(:goods_nomenclature_class) { create(:commodity, :non_declarable, :with_heading).goods_nomenclature_class }

      it { is_expected.to eq('Subheading') }
    end
  end

  describe '#consigned_from' do
    subject(:commodity) { create(:commodity, :with_description, description: 'Consigned from Türkiye') }

    it { expect(commodity.consigned_from).to eq('Türkiye') }
  end

  describe '#short_code' do
    subject(:short_code) { build(:commodity, goods_nomenclature_item_id: '0101210000').short_code }

    it { is_expected.to eq('0101210000') }
  end

  describe '#specific_system_short_code' do
    subject(:specific_system_short_code) { described_class.find(goods_nomenclature_item_id:).specific_system_short_code }

    before { create(:commodity, goods_nomenclature_item_id:) }

    context 'when the commodity is a harmonised system code' do
      let(:goods_nomenclature_item_id) { '0101210000' }

      it { is_expected.to eq('010121') }
    end

    context 'when the commodity is a combined nomenclature code' do
      let(:goods_nomenclature_item_id) { '0101210900' }

      it { is_expected.to eq('01012109') }
    end

    context 'when the commodity is a taric code' do
      let(:goods_nomenclature_item_id) { '0101210901' }

      it { is_expected.to eq('0101210901') }
    end
  end
end
