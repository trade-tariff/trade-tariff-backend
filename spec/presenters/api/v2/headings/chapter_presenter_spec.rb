RSpec.describe Api::V2::Headings::ChapterPresenter do
  subject(:presenter) { described_class.new chapter }

  let(:chapter) { create :chapter, :with_note }
  let!(:customs_tariff_update) { create(:customs_tariff_update, :approved) }
  let!(:customs_tariff_chapter_note) do
    create(:customs_tariff_chapter_note, :approved,
           customs_tariff_update:,
           chapter_id: chapter.short_code)
  end

  it { is_expected.to have_attributes goods_nomenclature_sid: chapter.goods_nomenclature_sid }
  it { is_expected.to have_attributes chapter_note: customs_tariff_chapter_note.content }
end
