RSpec.describe Api::V2::Headings::HeadingPresenter do
  subject(:presenter) { described_class.new heading }

  let(:heading) { create :heading, :with_chapter, :non_declarable }

  it { is_expected.to have_attributes goods_nomenclature_sid: heading.goods_nomenclature_sid }
  it { is_expected.to have_attributes section_id: heading.section.id }
  it { is_expected.to have_attributes chapter_id: heading.chapter.goods_nomenclature_sid }
  it { is_expected.to have_attributes section: instance_of(Api::V2::Headings::SectionPresenter) }
  it { is_expected.to have_attributes chapter: instance_of(Api::V2::Headings::ChapterPresenter) }

  it 'maps commodities to their presenter' do
    expect(presenter.commodities).to all be_instance_of Api::V2::Headings::CommodityPresenter
  end

  describe '#footnote_ids' do
    let :heading do
      create :heading, :with_chapter, :with_children, :with_footnote_association
    end

    it { is_expected.to have_attributes footnote_ids: heading.footnotes.map(&:footnote_id) }
  end
end
