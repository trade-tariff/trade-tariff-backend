RSpec.describe Api::V2::Subheadings::SectionPresenter do
  subject(:presenter) { described_class.new section }

  let(:section) { create :section, :with_note }

  it { is_expected.to have_attributes id: section.id }
  it { is_expected.to have_attributes section_note: section.section_note.content }
end
