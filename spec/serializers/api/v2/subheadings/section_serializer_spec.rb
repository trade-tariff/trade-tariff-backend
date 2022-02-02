RSpec.describe Api::V2::Subheadings::SectionSerializer do
  subject(:serializer) { described_class.new(serializable).serializable_hash.as_json }

  let(:serializable) { create(:section, :with_note) }

  let(:expected_pattern) do
    {
      data: {
        id: serializable.id.to_s,
        type: 'section',
        attributes: {
          numeral: serializable.numeral,
          title: serializable.title,
          position: serializable.position,
          section_note: serializable.section_note.as_json,
        },
      },
    }
  end

  describe '#serializable_hash' do
    it { is_expected.to include_json(expected_pattern) }
  end
end
