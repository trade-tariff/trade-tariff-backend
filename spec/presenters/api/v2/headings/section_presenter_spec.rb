RSpec.describe Api::V2::Headings::SectionPresenter do
  subject(:presenter) { described_class.new section }

  let(:section) { create :section, :with_note }
  let!(:customs_tariff_update) { create(:customs_tariff_update, :approved) }
  let!(:customs_tariff_section_note) do
    create(:customs_tariff_section_note, :approved,
           customs_tariff_update:,
           section_id: section.id)
  end

  it { is_expected.to have_attributes id: section.id }
  it { is_expected.to have_attributes section_note: customs_tariff_section_note.content }
end
