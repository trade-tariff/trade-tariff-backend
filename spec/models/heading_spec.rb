RSpec.describe Heading do
  describe '#to_param' do
    let(:heading) { create :heading }

    it 'uses first four digits of goods_nomenclature_item_id as param' do
      expect(
        heading.to_param,
      ).to eq heading.goods_nomenclature_item_id.first(4)
    end
  end

  describe '#changes' do
    let(:heading) { create :heading }

    it 'returns Sequel Dataset' do
      expect(heading.changes).to be_a Sequel::Dataset
    end

    context 'with Heading changes' do
      let!(:heading) { create :heading, operation_date: Time.zone.today }

      it 'includes Heading changes' do
        expect(
          heading.changes.select do |change|
            change.oid == heading.oid &&
            change.model == described_class
          end,
        ).to be_present
      end
    end

    context 'with associated Commodity changes' do
      let!(:heading)   { create :heading, operation_date: Time.zone.yesterday }
      let!(:commodity) do
        create :commodity,
               operation_date: Time.zone.yesterday,
               goods_nomenclature_item_id: "#{heading.short_code}000001"
      end

      it 'includes Commodity changes' do
        expect(
          heading.changes.select do |change|
            change.oid == commodity.oid &&
            change.model == Commodity
          end,
        ).to be_present
      end

      context 'with associated Measure (through Commodity) changes' do
        let!(:heading)   { create :heading, operation_date: Time.zone.yesterday }
        let!(:commodity) do
          create :commodity,
                 operation_date: Time.zone.yesterday,
                 goods_nomenclature_item_id: "#{heading.short_code}000001"
        end
        let!(:measure) do
          create :measure,
                 goods_nomenclature: commodity,
                 goods_nomenclature_item_id: commodity.goods_nomenclature_item_id,
                 operation_date: Time.zone.yesterday
        end

        it 'includes Measure changes' do
          expect(
            heading.changes.select do |change|
              change.oid == measure.oid &&
              change.model == Measure
            end,
          ).to be_present
        end
      end
    end
  end

  describe '#short_code' do
    let!(:heading) { create :heading, goods_nomenclature_item_id: '1234000000' }

    it 'returns first 4 chars of goods_nomenclature_item_id' do
      expect(heading.short_code).to eq('1234')
    end
  end

  describe '#goods_nomenclature_class' do
    subject { build(:heading).goods_nomenclature_class }

    it { is_expected.to eq('Heading') }
  end

  describe '.by_code' do
    let!(:heading1) { create(:heading, goods_nomenclature_item_id: '1234000000') }
    let!(:heading2) { create(:heading, goods_nomenclature_item_id: '4321000000') }

    it { expect(described_class.by_code('1234')).to be_a(Sequel::Dataset) }
    it { expect(described_class.by_code('1234')).to include(heading1) }
    it { expect(described_class.by_code('1234')).not_to include(heading2) }
  end
end
