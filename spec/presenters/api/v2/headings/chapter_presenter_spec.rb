RSpec.describe Api::V2::Headings::ChapterPresenter do
  subject(:presenter) { described_class.new chapter }

  let(:chapter) { create :chapter, :with_note }

  it { is_expected.to have_attributes goods_nomenclature_sid: chapter.goods_nomenclature_sid }
  it { is_expected.to have_attributes chapter_note: chapter.chapter_note.content }
end
