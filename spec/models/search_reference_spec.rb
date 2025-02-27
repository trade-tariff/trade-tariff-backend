RSpec.describe SearchReference do
  before do
    TradeTariffRequest.time_machine_now = Time.current
  end

  shared_examples_for 'a setter callback' do |referenced_factory|
    subject(:search_reference) { described_class.new(title: 'foo', referenced:) }

    let(:referenced) { create(referenced_factory) }

    it 'assigns the correct attributes' do
      expect(search_reference).to have_attributes(
        title: 'foo',
        referenced_class: referenced.class.name,
        productline_suffix: referenced.producline_suffix,
        goods_nomenclature_item_id: referenced.goods_nomenclature_item_id,
        goods_nomenclature_sid: referenced.goods_nomenclature_sid,
      )
    end
  end

  it_behaves_like 'a setter callback', :chapter
  it_behaves_like 'a setter callback', :heading
  it_behaves_like 'a setter callback', :commodity

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
        create(:subheading, goods_nomenclature_item_id: '0101110000', producline_suffix: '30')
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
          referenced_class: ['has to be associated to Chapter/Heading/Subheading/Commodity'],
        )
      end
    end
  end

  describe '#title_indexed' do
    subject(:search_reference) { build(:search_reference, title: 'foo, not bar') }

    it { expect(search_reference.title_indexed).to eq('foo') }
  end
end
