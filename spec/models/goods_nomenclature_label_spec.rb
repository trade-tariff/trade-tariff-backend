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

    context 'when goods_nomenclature_sid is nil and no goods_nomenclature is set' do
      subject(:label) { described_class.new(labels: { 'description' => 'Test' }) }

      before { label.valid? }

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

  describe '#before_validation' do
    subject(:label) { described_class.new(goods_nomenclature: goods_nomenclature, labels: { 'description' => 'Test' }) }

    let(:goods_nomenclature) { create(:commodity) }

    it 'sets goods_nomenclature_sid from goods_nomenclature' do
      label.save
      expect(label.goods_nomenclature_sid).to eq(goods_nomenclature.goods_nomenclature_sid)
    end

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

    it 'sets operation to C by default' do
      label.save
      expect(label[:operation]).to eq('C')
    end

    it 'sets operation_date to today by default' do
      label.save
      expect(label.operation_date).to eq(Time.zone.today)
    end

    it 'does not override explicitly set values' do
      label.goods_nomenclature_sid = 999
      label.save
      expect(label.goods_nomenclature_sid).to eq(999)
    end
  end

  describe '.build' do
    subject(:label) { described_class.build(goods_nomenclature, item) }

    let(:goods_nomenclature) { create(:commodity) }
    let(:item) do
      {
        'description' => 'A test description',
        'known_brands' => ['Brand A'],
        'colloquial_terms' => ['slang term'],
        'synonyms' => %w[synonym],
      }
    end

    it 'creates a label with the goods_nomenclature set' do
      expect(label.goods_nomenclature).to eq(goods_nomenclature)
    end

    it 'populates labels from the item' do
      expect(label.labels.to_h).to include(
        'description' => 'A test description',
        'known_brands' => ['Brand A'],
        'colloquial_terms' => ['slang term'],
        'synonyms' => %w[synonym],
      )
    end

    it 'includes original_description from classification_description' do
      expect(label.labels['original_description']).to eq(goods_nomenclature.classification_description)
    end

    it 'can be saved and populates all fields from before_create hook' do
      label.save

      expect(label.goods_nomenclature_sid).to eq(goods_nomenclature.goods_nomenclature_sid)
      expect(label.goods_nomenclature_item_id).to eq(goods_nomenclature.goods_nomenclature_item_id)
      expect(label.producline_suffix).to eq(goods_nomenclature.producline_suffix)
      expect(label.goods_nomenclature_type).to eq('Commodity')
    end

    context 'when an existing label exists' do
      before do
        create(
          :goods_nomenclature_label,
          goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid,
          goods_nomenclature: goods_nomenclature,
          labels: { 'known_brands' => ['Existing Brand'], 'synonyms' => ['existing synonym'] },
        )
      end

      it 'merges with existing label data' do
        expect(label.labels['known_brands']).to contain_exactly('Existing Brand', 'Brand A')
        expect(label.labels['synonyms']).to contain_exactly('existing synonym', 'synonym')
      end

      it 'sets operation to U for update' do
        expect(label[:operation]).to eq('U')
      end
    end
  end

  describe '#labels' do
    subject(:labels) { create(:goods_nomenclature_label, :with_labels).labels }

    it { is_expected.to be_a(Sequel::Postgres::JSONBHash) }
    it { expect(labels.keys).to include('brands', 'colloquialisms', 'descriptions', 'search_references', 'synonyms') }
  end

  describe '.goods_nomenclatures_dataset' do
    subject(:dataset) { described_class.goods_nomenclatures_dataset }

    it 'returns GoodsNomenclature dataset' do
      expect(dataset.model).to eq(GoodsNomenclature)
    end

    it 'takes into account TimeMachine.now' do
      expected_filter = '("goods_nomenclatures"."validity_start_date" <='
      expect(dataset.sql).to include(expected_filter)
    end

    it 'filters out goods nomenclatures that already have labels' do
      create(:goods_nomenclature_label, goods_nomenclature: create(:commodity))
      missing_label = create(:commodity)

      expect(dataset.map(&:goods_nomenclature_sid)).to eq([missing_label.goods_nomenclature_sid])
    end
  end
end
