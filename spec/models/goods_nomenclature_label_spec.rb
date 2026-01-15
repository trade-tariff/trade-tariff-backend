RSpec.describe GoodsNomenclatureLabel do
  before do
    TradeTariffRequest.time_machine_now = Time.current
  end

  describe 'validations' do
    subject(:label) { build(:goods_nomenclature_label, attributes) }

    let(:commodity) { create(:commodity) }

    before { label.valid? }

    context 'when all required fields are present' do
      let(:attributes) { {} }

      it { expect(label.errors).to be_empty }
    end

    context 'when goods_nomenclature_sid is nil' do
      let(:attributes) { { goods_nomenclature_sid: nil } }

      it { expect(label.errors).to include(:goods_nomenclature_sid) }
    end

    context 'when labels is nil' do
      let(:attributes) { { labels: nil } }

      it { expect(label.errors).to include(:labels) }
    end

    context 'when the label already exists for the same goods_nomenclature_sid and overlapping validity period' do
      let(:attributes) do
        {
          goods_nomenclature_sid: commodity.goods_nomenclature_sid,
          validity_start_date: 1.month.ago,
          validity_end_date: 1.month.from_now,
        }
      end

      before do
        create(
          :goods_nomenclature_label,
          goods_nomenclature_sid: commodity.goods_nomenclature_sid,
          validity_start_date: 2.months.ago,
          validity_end_date: 2.months.from_now,
        )
        label.valid?
      end

      it { expect(label.errors[:goods_nomenclature_sid]).to eq(['A label for this goods_nomenclature_sid already exists for the specified validity period']) }
    end
  end

  describe '#before_create' do
    subject(:label) { build(:goods_nomenclature_label, goods_nomenclature: goods_nomenclature) }

    let(:goods_nomenclature) { create(:commodity) }

    it 'sets validity_start_date from goods_nomenclature' do
      label.save
      expect(label.validity_start_date).to eq(goods_nomenclature.validity_start_date)
    end

    it 'sets validity_end_date from goods_nomenclature' do
      label.save
      expect(label.validity_end_date).to eq(goods_nomenclature.validity_end_date)
    end

    it 'sets goods_nomenclature_item_id from goods_nomenclature' do
      label.save
      expect(label.goods_nomenclature_item_id).to eq(goods_nomenclature.goods_nomenclature_item_id)
    end

    it 'sets producline_suffix from goods_nomenclature' do
      label.save
      expect(label.producline_suffix).to eq(goods_nomenclature.producline_suffix)
    end

    it 'sets goods_nomenclature_type from goods_nomenclature class name' do
      label.save
      expect(label.goods_nomenclature_type).to eq('Commodity')
    end

    it 'sets labels correctly' do
      label.save
      expect(label.labels).to eq('description' => 'Flibble')
    end
  end

  describe '#goods_nomenclature' do
    context 'when associated with a Commodity' do
      subject(:label) { create(:goods_nomenclature_label, :with_commodity) }

      it { expect(label.goods_nomenclature).to be_a(Commodity) }
      it { expect(label.goods_nomenclature_type).to eq('Commodity') }
    end

    context 'when associated with a Heading' do
      subject(:label) { create(:goods_nomenclature_label, :with_heading) }

      it { expect(label.goods_nomenclature).to be_a(Heading) }
      it { expect(label.goods_nomenclature_type).to eq('Heading') }
    end

    context 'when associated with a Chapter' do
      subject(:label) { create(:goods_nomenclature_label, :with_chapter) }

      it { expect(label.goods_nomenclature).to be_a(Chapter) }
      it { expect(label.goods_nomenclature_type).to eq('Chapter') }
    end
  end

  describe '#labels' do
    subject(:labels) { create(:goods_nomenclature_label, :with_commodity, :with_labels).labels }

    it { is_expected.to be_a(Sequel::Postgres::JSONBHash) }
    it { expect(labels.keys).to include('brands', 'colloquialisms', 'descriptions', 'search_references', 'synonyms') }
  end
end
