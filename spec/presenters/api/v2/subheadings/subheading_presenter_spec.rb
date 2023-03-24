RSpec.describe Api::V2::Subheadings::SubheadingPresenter do
  subject(:presenter) { described_class.new subheading }

  let(:subheading) { create :subheading, :with_chapter_and_heading, :with_children }

  it { is_expected.to have_attributes goods_nomenclature_sid: subheading.goods_nomenclature_sid }
  it { is_expected.to have_attributes heading_id: subheading.heading.goods_nomenclature_sid }
  it { is_expected.to have_attributes chapter_id: subheading.chapter.goods_nomenclature_sid }
  it { is_expected.to have_attributes section: instance_of(Api::V2::Subheadings::SectionPresenter) }
  it { is_expected.to have_attributes chapter: instance_of(Api::V2::Subheadings::ChapterPresenter) }
  it { is_expected.to have_attributes ancestors: [] }

  it 'includes ancestors and self in commodities' do
    commodities = subheading.ns_ancestors.select { |anc| anc.number_indents.positive? }
    commodities << subheading
    commodities += subheading.ns_descendants

    expect(presenter.commodity_ids).to eq commodities.map(&:goods_nomenclature_sid)
  end

  it 'maps commodities to their presenter' do
    expect(presenter.commodities).to all be_instance_of Api::V2::Subheadings::CommodityPresenter
  end

  context 'for subsubheading' do
    subject(:presenter) { described_class.new leaf }

    let(:leaf) { subheading.ns_children.first }
    let(:leaf_commodities) { [leaf.ns_parent, leaf] + leaf.ns_descendants }

    it { is_expected.to have_attributes ancestors: [leaf.ns_parent] }
    it { is_expected.to have_attributes commodity_ids: leaf_commodities.map(&:pk) }
  end
end
