RSpec.describe SearchReference do
  describe 'setter callback' do
    subject(:search_reference) { described_class.new(title: 'foo', referenced:) }

    context 'when setting a Section reference' do
      let(:referenced) { create(:section, id: 1) }

      it { is_expected.to have_attributes(title: 'foo', referenced_id: '1', referenced_class: 'Section', productline_suffix: '80') }
    end

    context 'when setting a Chapter reference' do
      let(:referenced) { create(:chapter, goods_nomenclature_item_id: '0100000000', producline_suffix: '10') }

      it { is_expected.to have_attributes(title: 'foo', referenced_id: '01', referenced_class: 'Chapter', productline_suffix: '10') }
    end

    context 'when setting a Heading reference' do
      let(:referenced) { create(:heading, goods_nomenclature_item_id: '0101000000', producline_suffix: '20') }

      it { is_expected.to have_attributes(title: 'foo', referenced_id: '0101', referenced_class: 'Heading', productline_suffix: '20') }
    end

    context 'when setting a Subheading reference' do
      let(:referenced) { Subheading.find(goods_nomenclature_item_id: '0101110000', producline_suffix: '30') }

      before { create(:commodity, goods_nomenclature_item_id: '0101110000', producline_suffix: '30') }

      it { is_expected.to have_attributes(title: 'foo', referenced_id: '0101110000', referenced_class: 'Subheading', productline_suffix: '30') }
    end

    context 'when setting a Commodity reference' do
      let(:referenced) { create(:commodity, :with_heading, goods_nomenclature_item_id: '0101110000', producline_suffix: '80') }

      it { is_expected.to have_attributes(title: 'foo', referenced_id: '0101110000', referenced_class: 'Commodity', productline_suffix: '80') }
    end
  end

  describe '#referenced' do
    subject(:search_reference) { described_class.find(title: 'foo') }

    before do
      create(:search_reference, title: 'foo', referenced:)
    end

    context 'when getting a Chapter reference' do
      let(:referenced) { create(:chapter, goods_nomenclature_item_id: '0100000000', producline_suffix: '10') }

      it { expect(search_reference.referenced).to be_a(Chapter) }
    end

    context 'when getting a Heading reference' do
      let(:referenced) { create(:heading, goods_nomenclature_item_id: '0101000000', producline_suffix: '20') }

      it { expect(search_reference.referenced).to be_a(Heading) }
    end

    context 'when getting a Commodity reference' do
      let(:referenced) { create(:commodity, goods_nomenclature_item_id: '0101110000', producline_suffix: '80') }

      it { expect(search_reference.referenced).to be_a(Commodity) }
    end

    context 'when getting a Subheading reference' do
      let(:referenced) do
        create(:commodity, goods_nomenclature_item_id: '0101110000', producline_suffix: '30')

        Subheading.find(goods_nomenclature_item_id: '0101110000', producline_suffix: '30')
      end

      it { expect(search_reference.referenced).to be_a(Subheading) }
    end
  end

  describe 'validations' do
    before { search_reference.validate }

    context 'when the title is nil' do
      subject(:search_reference) { build(:search_reference, title: nil) }

      it { expect(search_reference.errors).to eq(title: ['missing title']) }
    end

    context 'when the referenced entity is not passed' do
      subject(:search_reference) { build(:search_reference, referenced: nil) }

      it 'attaches the correct missing reference errors' do
        expect(search_reference.errors).to eq(
          productline_suffix: ['missing productline suffix'],
          referenced_id: ['has to be associated to Chapter/Heading/Subheading/Commodity'],
          referenced_class: ['has to be associated to Chapter/Heading/Subheading/Commodity'],
        )
      end
    end
  end

  describe '#resource_path' do
    subject(:resource_path) { create(:search_reference, trait).resource_path }

    context 'when referenced is a chapter' do
      let(:trait) { :with_chapter }

      it { is_expected.to eq('/chapters/01') }
    end

    context 'when referenced is a heading' do
      let(:trait) { :with_heading }

      it { is_expected.to eq('/headings/0101') }
    end

    context 'when referenced is a subheading' do
      let(:trait) { :with_subheading }

      it { is_expected.to eq('/subheadings/0101210000-10') }
    end

    context 'when referenced is a commodity' do
      let(:trait) { :with_commodity }

      it { is_expected.to eq('/commodities/0101291000') }
    end
  end

  describe '.count_for' do
    subject { described_class.count_for commodities.slice(0, 2) }

    before { search_references }

    let(:commodities) { create_list :commodity, 3 }

    let :search_references do
      commodities.map { |c| create :search_reference, referenced: c } +
        create_list(:search_reference, 1, referenced: commodities.first)
    end

    it { is_expected.to include commodities.first.twelvedigit => 2 }
    it { is_expected.to include commodities.second.twelvedigit => 1 }
    it { is_expected.not_to include commodities.third.twelvedigit => 0 }
  end
end
