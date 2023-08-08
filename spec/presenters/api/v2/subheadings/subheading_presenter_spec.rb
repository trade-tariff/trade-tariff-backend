RSpec.describe Api::V2::Subheadings::SubheadingPresenter do
  subject(:presenter) { described_class.new subheading }

  let(:subheading) { create :subheading, :with_chapter_and_heading, :with_children }

  it { is_expected.to have_attributes goods_nomenclature_sid: subheading.goods_nomenclature_sid }
  it { is_expected.to have_attributes section_id: subheading.chapter.section.id }
  it { is_expected.to have_attributes heading_id: subheading.heading.goods_nomenclature_sid }
  it { is_expected.to have_attributes chapter_id: subheading.chapter.goods_nomenclature_sid }
  it { is_expected.to have_attributes section: instance_of(Api::V2::Headings::SectionPresenter) }
  it { is_expected.to have_attributes chapter: instance_of(Api::V2::Headings::ChapterPresenter) }
  it { is_expected.to have_attributes ten_digit_ancestors: [] }

  it 'includes ancestors and self in commodities' do
    commodities = subheading.ancestors.select { |anc| anc.number_indents.positive? }
    commodities << subheading
    commodities += subheading.descendants

    expect(presenter.commodity_ids).to eq commodities.map(&:goods_nomenclature_sid)
  end

  it { expect(presenter.commodities).to all(be_instance_of(Api::V2::Headings::CommodityPresenter)) }

  context 'for subsubheading' do
    subject(:presenter) { described_class.new leaf }

    let(:leaf) { subheading.children.first }
    let(:leaf_commodities) { [leaf.parent, leaf] + leaf.descendants }

    it { is_expected.to have_attributes ten_digit_ancestors: [leaf.parent] }
    it { is_expected.to have_attributes commodity_ids: leaf_commodities.map(&:pk) }
  end

  describe '#footnote_ids' do
    let :subheading do
      create :subheading, :with_chapter_and_heading, :with_children, :with_footnote_association
    end

    it { is_expected.to have_attributes footnote_ids: subheading.footnotes.map(&:id) }
  end
end
