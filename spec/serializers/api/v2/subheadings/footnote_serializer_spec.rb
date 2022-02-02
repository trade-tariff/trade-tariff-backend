RSpec.describe Api::V2::Subheadings::FootnoteSerializer do
  subject(:serializer) { described_class.new(serializable).serializable_hash.as_json }

  let(:serializable) { create(:footnote, footnote_id: '037', footnote_type_id: 'TR') }

  let(:expected_pattern) do
    {
      data: {
        id: serializable.footnote_id,
        type: 'footnote',
        attributes: {
          code: 'TR037',
          description: serializable.description,
          formatted_description: serializable.formatted_description,
        },
      },
    }
  end

  describe '#serializable_hash' do
    it { is_expected.to include_json(expected_pattern) }
  end
end
