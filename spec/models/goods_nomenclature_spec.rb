RSpec.describe GoodsNomenclature do
  before do
    TradeTariffRequest.time_machine_now = Time.current
  end

  describe '#full_chemicals' do
    subject(:full_chemicals) { create(:goods_nomenclature, :with_full_chemicals).full_chemicals }

    it { is_expected.to all(be_a(FullChemical)) }
  end

  describe 'ordering', :flaky do
    subject(:goods_nomenclatures) { described_class.all.pluck(:goods_nomenclature_item_id, :producline_suffix) }

    before do
      create(:commodity, producline_suffix: '80', goods_nomenclature_item_id: '0101210000')
      create(:heading, producline_suffix: '80', goods_nomenclature_item_id: '0102000000')
      create(:chapter, producline_suffix: '80', goods_nomenclature_item_id: '0100000000')
      create(:heading, producline_suffix: '80', goods_nomenclature_item_id: '0101000000')
      create(:commodity, producline_suffix: '10', goods_nomenclature_item_id: '0101210000')
    end

    let(:expected_goods_nomenclatures) do
      [
        %w[0100000000 80],
        %w[0101000000 80],
        %w[0101210000 10], # Included producline suffix in composite ordering
        %w[0101210000 80],
        %w[0102000000 80],
      ]
    end

    it { expect(goods_nomenclatures).to eq(expected_goods_nomenclatures) }
  end

  describe 'single table inheritance loader' do
    shared_examples 'it loads data into the correct class' do |klass, *traits|
      subject do
        described_class.where(goods_nomenclature_sid: gn.goods_nomenclature_sid)
                       .first
      end

      let(:gn) { create(:goods_nomenclature, *traits) }

      it { is_expected.to be_instance_of klass }
    end

    it_behaves_like 'it loads data into the correct class', Chapter, :chapter
    it_behaves_like 'it loads data into the correct class', Heading, :heading
    it_behaves_like 'it loads data into the correct class', Commodity, :with_children
    it_behaves_like 'it loads data into the correct class', Commodity
  end

  describe '#code' do
    let(:gono) { create(:goods_nomenclature, goods_nomenclature_item_id: '8056116321') }

    it 'returns goods_nomenclature_item_id' do
      expect(gono.code).to eq('8056116321')
    end
  end

  describe '#bti_url' do
    let(:bti_url) do
      'https://www.gov.uk/guidance/check-what-youll-need-to-get-a-legally-binding-decision-on-a-commodity-code'
    end

    let(:gono) { create(:goods_nomenclature) }

    it 'includes gono code' do
      expect(gono.bti_url).to include(bti_url)
    end
  end

  describe '#chapter_id' do
    let(:gono) { create(:goods_nomenclature, goods_nomenclature_item_id: '8056116321') }

    it 'includes first to chars' do
      expect(gono.chapter_id).to include(gono.goods_nomenclature_item_id.first(2))
    end

    it 'includes eight 0' do
      expect(gono.chapter_id).to include('0' * 8)
    end
  end

  describe '#chapter_code' do
    subject(:chapter_code) { create(:goods_nomenclature, goods_nomenclature_item_id: '0101210000').chapter_code }

    it { is_expected.to eq('0100000000') }
  end

  describe '#heading_code' do
    subject(:heading_code) { create(:goods_nomenclature, goods_nomenclature_item_id: '0101210000').heading_code }

    it { is_expected.to eq('0101000000') }
  end

  describe '#to_s' do
    let(:gono) { create(:commodity, goods_nomenclature_item_id: '8056116321', indents: 4) }

    it 'includes number_indents' do
      expect(gono.to_s).to include(gono.number_indents.to_s)
    end

    it 'includes goods_nomenclature_item_id' do
      expect(gono.to_s).to include(gono.goods_nomenclature_item_id)
    end
  end

  describe '#goods_nomenclature_class' do
    context 'when the GoodsNomenclature is a Commodity' do
      subject(:goods_nomenclature_class) { create(:commodity, :declarable, :with_heading).goods_nomenclature_class }

      it { is_expected.to eq('Commodity') }
    end

    context 'when the GoodsNomenclature is a Subheading' do
      subject(:goods_nomenclature_class) { create(:commodity, :non_declarable, :with_heading).goods_nomenclature_class }

      it { is_expected.to eq('Subheading') }
    end

    context 'when the GoodsNomenclature is a Heading' do
      subject(:goods_nomenclature_class) { create(:heading).goods_nomenclature_class }

      it { is_expected.to eq('Heading') }
    end

    context 'when the GoodsNomenclature is a Chapter' do
      subject(:goods_nomenclature_class) { create(:chapter).goods_nomenclature_class }

      it { is_expected.to eq('Chapter') }
    end
  end

  describe '#chapter' do
    before do
      create(:chapter, goods_nomenclature_item_id: '0100000000')
    end

    context 'when the goods nomenclature is a chapter' do
      subject(:chapter) { create(:chapter, goods_nomenclature_item_id: '0100000000') }

      it { is_expected.to be_a(Chapter) }
    end

    context 'when the goods nomenclature is a heading' do
      subject(:chapter) { create(:heading, goods_nomenclature_item_id: '0101000000').chapter }

      it { is_expected.to be_a(Chapter) }
    end

    context 'when the goods nomenclature is a commodity' do
      subject(:chapter) { create(:commodity, goods_nomenclature_item_id: '0111110000').chapter }

      it { is_expected.to be_a(Chapter) }
    end
  end

  describe '#heading?' do
    context 'when the goods nomenclature has a heading goods nomenclature item id' do
      subject(:goods_nomenclature) { create(:goods_nomenclature, :heading) }

      it { is_expected.to be_heading }
    end

    context 'when the goods nomenclature has a non-heading goods nomenclature item id' do
      subject(:goods_nomenclature) { create(:goods_nomenclature, :commodity) }

      it { is_expected.not_to be_heading }
    end
  end

  describe '#chapter?' do
    context 'when the goods nomenclature has a chapter goods nomenclature item id' do
      subject(:goods_nomenclature) { create(:goods_nomenclature, :chapter) }

      it { is_expected.to be_chapter }
    end

    context 'when the goods nomenclature has a non-chapter goods nomenclature item id' do
      subject(:goods_nomenclature) { create(:goods_nomenclature, :commodity) }

      it { is_expected.not_to be_chapter }
    end
  end

  describe '#classified?' do
    context 'when the goods nomenclature is part of the classified chapter' do
      subject(:goods_nomenclature) { create(:goods_nomenclature, goods_nomenclature_item_id: '9800000000').reload }

      it { is_expected.to be_classified }
    end

    context 'when the goods nomenclature is not part of the classified chapter' do
      subject(:goods_nomenclature) { create(:goods_nomenclature, goods_nomenclature_item_id: '9900000000') }

      it { is_expected.not_to be_classified }
    end
  end

  describe '#classifiable_goods_nomenclatures' do
    subject(:classifiable_goods_nomenclatures) do
      described_class
        .find(goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid)
        .classifiable_goods_nomenclatures
        .pluck(:goods_nomenclature_sid)
    end

    context 'when there are ancestors for the current goods nomenclature' do
      let(:goods_nomenclature) { create(:commodity, :with_ancestors) }

      let(:gn_sids) { [goods_nomenclature.goods_nomenclature_sid, 2, 1] }

      it { expect(classifiable_goods_nomenclatures).to eq(gn_sids) }
    end

    context 'when there are no ancestors for the current goods nomenclature' do
      let(:goods_nomenclature) { create(:commodity) }

      let(:gn_sids) { [goods_nomenclature.goods_nomenclature_sid] }

      it { expect(classifiable_goods_nomenclatures).to eq(gn_sids) }
    end
  end

  describe '#goods_nomenclature_descriptions' do
    context 'when the description column is null' do
      subject(:goods_nomenclature_descriptions) do
        create(
          :goods_nomenclature,
          :with_description,
          description: nil,
        ).goods_nomenclature_descriptions
      end

      it { is_expected.to be_empty }
    end

    context 'when the description column is not null' do
      subject(:goods_nomenclature_descriptions) do
        create(
          :goods_nomenclature,
          :with_description,
          description: 'foo',
        ).goods_nomenclature_descriptions
      end

      it { is_expected.not_to be_empty }
    end
  end

  describe '#to_admin_param' do
    subject { goods_nomenclature.to_admin_param }

    let(:goods_nomenclature) { create(:goods_nomenclature) }

    it { is_expected.to eq(goods_nomenclature.to_param) }
  end

  describe '#has_chemicals' do
    context 'when the goods nomenclature has no chemicals' do
      subject(:has_chemicals) { create(:goods_nomenclature).has_chemicals }

      it { is_expected.to be(false) }
    end

    context 'when the goods nomenclature has chemicals' do
      subject(:has_chemicals) { create(:goods_nomenclature, :with_full_chemicals).has_chemicals }

      it { is_expected.to be(true) }
    end
  end

  describe '#non_grouping?' do
    context 'when the commodity has a non-grouping producline_suffix' do
      subject(:commodity) { create(:commodity, :non_grouping) }

      it { is_expected.to be_non_grouping }
    end

    context 'when the commodity has a grouping producline_suffix' do
      subject(:commodity) { create(:commodity, :grouping) }

      it { is_expected.not_to be_non_grouping }
    end
  end

  describe '#grouping?' do
    context 'when the commodity has a grouping producline_suffix' do
      subject(:commodity) { create(:commodity, :grouping) }

      it { is_expected.to be_grouping }
    end

    context 'when the commodity has a non-grouping producline_suffix' do
      subject(:commodity) { create(:commodity, :non_grouping) }

      it { is_expected.not_to be_grouping }
    end
  end

  describe '.non_classifieds' do
    subject(:non_classifieds) { described_class.non_classifieds.pluck(:goods_nomenclature_item_id) }

    before do
      create(:goods_nomenclature, :classified)
      create(:goods_nomenclature, goods_nomenclature_item_id: '0111110000')
    end

    it { is_expected.to eq(%w[0111110000]) }
  end

  describe '.non_grouping' do
    subject(:non_grouping) { described_class.non_grouping.pluck(:goods_nomenclature_item_id) }

    before do
      create(:goods_nomenclature, :non_grouping, goods_nomenclature_item_id: '0111110000')
      create(:goods_nomenclature, :grouping)
    end

    it { is_expected.to eq(%w[0111110000]) }
  end

  describe '#cast_to' do
    subject(:casted) { commodity.cast_to Subheading }

    let(:commodity) { create(:commodity) }

    it { is_expected.to be_instance_of Subheading }
    it { is_expected.to have_attributes values: commodity.values }
    it { is_expected.not_to have_attributes object_id: commodity.object_id }

    context 'with loaded relationships' do
      subject { casted.associations }

      before { commodity.tree_node }

      it { is_expected.to include tree_node: be_present }
    end

    context 'when already matching type' do
      subject { commodity.cast_to described_class }

      it { is_expected.to have_attributes object_id: commodity.object_id }
    end
  end

  describe '#sti_cast' do
    subject { goods_nomenclature.sti_cast }

    let(:goods_nomenclature) { create(:commodity) }

    context 'with declarable' do
      it { is_expected.to be_instance_of Commodity }
      it { is_expected.to have_attributes values: goods_nomenclature.values }
    end

    context 'with non declarable' do
      before { create :commodity, parent: goods_nomenclature }

      it { is_expected.to be_instance_of Subheading }
      it { is_expected.to have_attributes values: goods_nomenclature.values }
    end

    context 'with heading' do
      let(:goods_nomenclature) { create :heading }

      it { is_expected.to have_attributes object_id: goods_nomenclature.object_id }
    end

    context 'with chapter' do
      let(:goods_nomenclature) { create :chapter }

      it { is_expected.to have_attributes object_id: goods_nomenclature.object_id }
    end
  end

  describe '.join_footnotes' do
    subject(:goods_nomenclatures) { described_class.join_footnotes.all }

    before do
      goods_nomenclature = create(:goods_nomenclature)

      # create multiple footnotes associated with our goods nomenclature
      create(:footnote, :with_goods_nomenclature_association, goods_nomenclature:)
      create(:footnote, :with_goods_nomenclature_association, goods_nomenclature:)

      # create a footnote with no existing goods nomenclature - excluded
      create(:footnote, :with_goods_nomenclature_association)

      # create a footnote not associated with a goods nomenclature - excluded
      create(:footnote)
    end

    it { is_expected.to all(be_a(described_class)) }
    it { expect(goods_nomenclatures.first).to eq_pk goods_nomenclatures.second }
    it { expect(goods_nomenclatures.count).to eq(2) }
    it { expect(goods_nomenclatures.pluck(:footnote_id)).to all(be_present) }
    it { expect(goods_nomenclatures.pluck(:footnote_type_id)).to all(be_present) }
  end

  describe '.with_footnote_type_id' do
    subject(:dataset) { described_class.join_footnotes.with_footnote_type_id('01') }

    before do
      goods_nomenclature = create(:goods_nomenclature)

      create(:footnote, :with_goods_nomenclature_association, goods_nomenclature:, footnote_type_id: '01')
      create(:footnote, :with_goods_nomenclature_association, goods_nomenclature:, footnote_type_id: '02')
    end

    it { is_expected.to all(be_a(described_class)) }
    it { expect(dataset.pluck(:footnote_type_id)).to eq(%w[01]) }
  end

  describe '.with_footnote_id' do
    subject(:dataset) { described_class.join_footnotes.with_footnote_id('123') }

    before do
      goods_nomenclature = create(:goods_nomenclature)

      create(:footnote, :with_goods_nomenclature_association, goods_nomenclature:, footnote_id: '123')
      create(:footnote, :with_goods_nomenclature_association, goods_nomenclature:, footnote_id: '456')
    end

    it { is_expected.to all(be_a(described_class)) }
    it { expect(dataset.pluck(:footnote_id)).to eq(%w[123]) }
  end

  describe '.with_footnote_types_and_ids' do
    subject(:dataset) { described_class.join_footnotes.with_footnote_types_and_ids(footnote_types_and_ids) }

    before do
      goods_nomenclature = create(:goods_nomenclature)

      create(
        :footnote,
        :with_goods_nomenclature_association,
        goods_nomenclature:,
        footnote_type_id: 'Y',
        footnote_id: '123',
      )
      create(
        :footnote,
        :with_goods_nomenclature_association,
        goods_nomenclature:,
        footnote_type_id: 'N',
        footnote_id: '456',
      )
      create(
        :footnote,
        :with_goods_nomenclature_association,
        goods_nomenclature:,
        footnote_type_id: 'Z',
        footnote_id: '789',
      )
    end

    context 'when footnote_types_and_ids is empty' do
      let(:footnote_types_and_ids) { [] }

      it { expect(dataset.pluck(:footnote_id)).to eq %w[123 456 789] }
      it { expect(dataset.pluck(:footnote_type_id)).to eq %w[Y N Z] }
    end

    context 'when footnote_types_and_ids is present' do
      let(:footnote_types_and_ids) do
        [
          %w[Y 123],
          %w[N 456],
        ]
      end

      it { expect(dataset.pluck(:footnote_id)).to eq %w[123 456] }
      it { expect(dataset.pluck(:footnote_type_id)).to eq %w[Y N] }
    end
  end

  describe '#green_lanes_measures' do
    subject { goods_nomenclature.green_lanes_measures }

    let :goods_nomenclature do
      create(:commodity).tap do |gn|
        create :green_lanes_measure, goods_nomenclature: gn
      end
    end

    it { is_expected.to include instance_of GreenLanes::Measure }
  end
end
