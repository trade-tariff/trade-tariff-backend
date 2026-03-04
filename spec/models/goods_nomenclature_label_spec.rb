RSpec.describe GoodsNomenclatureLabel do
  before do
    TradeTariffRequest.time_machine_now = Time.current
  end

  describe 'validations' do
    subject(:label) { build(:goods_nomenclature_label, attributes) }

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
  end

  describe '#before_validation' do
    subject(:label) { described_class.new(goods_nomenclature: goods_nomenclature, labels: { 'description' => 'Test' }) }

    let(:goods_nomenclature) { create(:commodity) }

    it 'sets goods_nomenclature_sid from goods_nomenclature' do
      label.save
      expect(label.goods_nomenclature_sid).to eq(goods_nomenclature.goods_nomenclature_sid)
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

    it 'populates structured columns from the item' do
      expect(label.description).to eq('A test description')
      expect(label.known_brands.to_a).to eq(['Brand A'])
      expect(label.colloquial_terms.to_a).to eq(['slang term'])
      expect(label.synonyms.to_a).to eq(%w[synonym])
    end

    it 'includes original_description from classification_description by default' do
      expect(label.labels['original_description']).to eq(goods_nomenclature.classification_description)
      expect(label.original_description).to eq(goods_nomenclature.classification_description)
    end

    it 'computes context_hash from the description' do
      expected = Digest::SHA256.hexdigest(goods_nomenclature.classification_description.to_s)
      expect(label.context_hash).to eq(expected)
    end

    context 'with contextual_description provided' do
      subject(:label) { described_class.build(goods_nomenclature, item, contextual_description: 'Full contextual description') }

      it 'uses the provided contextual_description as original_description' do
        expect(label.labels['original_description']).to eq('Full contextual description')
        expect(label.original_description).to eq('Full contextual description')
      end

      it 'computes context_hash from the contextual_description' do
        expected = Digest::SHA256.hexdigest('Full contextual description')
        expect(label.context_hash).to eq(expected)
      end
    end

    context 'with nil contextual_description' do
      subject(:label) { described_class.build(goods_nomenclature, item, contextual_description: nil) }

      it 'falls back to classification_description' do
        expect(label.labels['original_description']).to eq(goods_nomenclature.classification_description)
      end
    end

    it 'can be saved and populates all fields from before_validation hook' do
      label.save

      expect(label.goods_nomenclature_sid).to eq(goods_nomenclature.goods_nomenclature_sid)
      expect(label.goods_nomenclature_item_id).to eq(goods_nomenclature.goods_nomenclature_item_id)
      expect(label.producline_suffix).to eq(goods_nomenclature.producline_suffix)
      expect(label.goods_nomenclature_type).to eq('Commodity')
    end
  end

  describe '#mark_stale!' do
    it 'sets stale to true' do
      label = create(:goods_nomenclature_label)
      label.mark_stale!
      expect(label.reload.stale).to be true
    end
  end

  describe '#context_stale?' do
    it 'returns true when hash differs' do
      label = create(:goods_nomenclature_label, context_hash: 'abc')
      expect(label.context_stale?('xyz')).to be true
    end

    it 'returns false when hash matches' do
      label = create(:goods_nomenclature_label, context_hash: 'abc')
      expect(label.context_stale?('abc')).to be false
    end
  end

  describe '.stale' do
    it 'returns only stale labels' do
      stale_label = create(:goods_nomenclature_label, :stale)
      create(:goods_nomenclature_label)

      expect(described_class.stale.all).to eq([stale_label])
    end
  end

  describe '.needing_relabel' do
    it 'returns stale non-manually-edited labels' do
      relabel_label = create(:goods_nomenclature_label, :stale)
      create(:goods_nomenclature_label, :stale, :manually_edited)
      create(:goods_nomenclature_label)

      expect(described_class.needing_relabel.all).to eq([relabel_label])
    end
  end

  describe '#labels' do
    subject(:labels) { create(:goods_nomenclature_label, :with_labels).labels }

    it { is_expected.to be_a(Sequel::Postgres::JSONBHash) }
    it { expect(labels.keys).to include('description', 'colloquial_terms', 'known_brands', 'synonyms') }
  end

  describe '.admin_listing' do
    let(:commodity) { create(:goods_nomenclature, producline_suffix: '80') }

    before do
      create(:goods_nomenclature_label,
             goods_nomenclature: commodity,
             description_score: 0.75)
    end

    it 'returns labels joined with goods_nomenclatures' do
      results = described_class.admin_listing.all
      expect(results.length).to eq(1)
    end

    it 'includes a computed score from description_score' do
      result = described_class.admin_listing.first
      expect(result[:score]).to eq(0.75)
    end

    it 'includes a computed nomenclature_type' do
      result = described_class.admin_listing.first
      expect(result[:nomenclature_type]).to be_present
    end

    it 'returns nil score when description_score is nil' do
      described_class.dataset.update(description_score: nil)
      result = described_class.admin_listing.first
      expect(result[:score]).to be_nil
    end
  end

  describe '.search' do
    let(:commodity) { create(:goods_nomenclature, goods_nomenclature_item_id: '0201100000', producline_suffix: '80') }

    before do
      create(:goods_nomenclature_label,
             goods_nomenclature: commodity,
             description: 'Fresh beef carcasses',
             synonyms: Sequel.pg_array(['bovine meat'], :text),
             colloquial_terms: Sequel.pg_array(['beef cuts'], :text),
             known_brands: Sequel.pg_array(%w[Angus], :text),
             labels: { 'description' => 'Fresh beef carcasses' })
    end

    it 'searches by commodity code prefix' do
      results = described_class.admin_listing.search('0201').all
      expect(results.length).to eq(1)
    end

    it 'searches by description text' do
      results = described_class.admin_listing.search('beef').all
      expect(results.length).to eq(1)
    end

    it 'searches by synonyms' do
      results = described_class.admin_listing.search('bovine').all
      expect(results.length).to eq(1)
    end

    it 'searches by colloquial terms' do
      results = described_class.admin_listing.search('beef cuts').all
      expect(results.length).to eq(1)
    end

    it 'searches by known brands' do
      results = described_class.admin_listing.search('Angus').all
      expect(results.length).to eq(1)
    end

    it 'returns all when query is blank' do
      results = described_class.admin_listing.search('').all
      expect(results.length).to eq(1)
    end

    it 'returns all when query is a single non-numeric character' do
      results = described_class.admin_listing.search('a').all
      expect(results.length).to eq(1)
    end
  end

  describe '.for_status' do
    let(:commodity_a) { create(:goods_nomenclature, producline_suffix: '80') }
    let(:commodity_b) { create(:goods_nomenclature, producline_suffix: '80') }

    before do
      create(:goods_nomenclature_label, :stale, goods_nomenclature: commodity_a)
      create(:goods_nomenclature_label, :manually_edited, goods_nomenclature: commodity_b)
    end

    it 'filters to stale labels' do
      results = described_class.admin_listing.for_status('stale').all
      expect(results.length).to eq(1)
      expect(results.first.stale).to be true
    end

    it 'filters to manually edited labels' do
      results = described_class.admin_listing.for_status('manually_edited').all
      expect(results.length).to eq(1)
      expect(results.first.manually_edited).to be true
    end

    it 'returns all for unrecognised status' do
      results = described_class.admin_listing.for_status('unknown').all
      expect(results.length).to eq(2)
    end
  end

  describe '.for_score_category' do
    let(:commodity_bad) { create(:goods_nomenclature, producline_suffix: '80') }
    let(:commodity_good) { create(:goods_nomenclature, producline_suffix: '80') }
    let(:commodity_nil) { create(:goods_nomenclature, producline_suffix: '80') }

    before do
      create(:goods_nomenclature_label, goods_nomenclature: commodity_bad, description_score: 0.2)
      create(:goods_nomenclature_label, goods_nomenclature: commodity_good, description_score: 0.6)
      create(:goods_nomenclature_label, goods_nomenclature: commodity_nil, description_score: nil)
    end

    it 'filters bad scores (below 0.3)' do
      results = described_class.admin_listing.for_score_category('bad').all
      expect(results.map { |r| r[:score] }).to all(be < 0.3)
    end

    it 'filters good scores (0.5 to 0.85)' do
      results = described_class.admin_listing.for_score_category('good').all
      expect(results.map { |r| r[:score] }).to all(be >= 0.5)
    end

    it 'filters no_score' do
      results = described_class.admin_listing.for_score_category('no_score').all
      expect(results.map { |r| r[:score] }).to all(be_nil)
    end

    it 'returns all for unrecognised category' do
      results = described_class.admin_listing.for_score_category('unknown').all
      expect(results.length).to eq(3)
    end
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

    it 'includes goods nomenclatures without labels' do
      create(:goods_nomenclature_label, goods_nomenclature: create(:commodity))
      missing_label = create(:commodity)

      expect(dataset.map(&:goods_nomenclature_sid)).to include(missing_label.goods_nomenclature_sid)
    end

    it 'includes goods nomenclatures with stale non-manually-edited labels' do
      commodity = create(:commodity)
      create(:goods_nomenclature_label, :stale, goods_nomenclature: commodity)

      expect(dataset.map(&:goods_nomenclature_sid)).to include(commodity.goods_nomenclature_sid)
    end

    it 'excludes goods nomenclatures with stale manually-edited labels' do
      commodity = create(:commodity)
      create(:goods_nomenclature_label, :stale, :manually_edited, goods_nomenclature: commodity)

      expect(dataset.map(&:goods_nomenclature_sid)).not_to include(commodity.goods_nomenclature_sid)
    end

    it 'excludes goods nomenclatures with fresh labels' do
      commodity = create(:commodity)
      create(:goods_nomenclature_label, goods_nomenclature: commodity)

      expect(dataset.map(&:goods_nomenclature_sid)).not_to include(commodity.goods_nomenclature_sid)
    end
  end
end
