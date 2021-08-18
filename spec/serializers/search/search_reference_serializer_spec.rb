describe Search::SearchReferenceSerializer do
  describe '#to_json' do
    context 'when there is a valid referenced object' do
      let(:section) { create :section, position: 12 }
      let(:search_reference) { described_class.new(create(:search_reference, referenced: section)) }
      let(:pattern) do
        {
          title: search_reference.title,
          reference_class: String,
          reference: {
            class: 'Section',
          }.ignore_extra_keys!,
        }
      end

      it 'returns rendered referenced entity as json' do
        section

        expect(search_reference.to_json).to match_json_expression pattern
      end
    end

    context 'when there is no valid referenced object' do
      let(:search_reference) do
        described_class.new(
          create(:search_reference,
                 section_id: nil,
                 chapter_id: nil,
                 heading_id: nil,
                 referenced: nil),
        )
      end

      it 'returns blank json hash' do
        expect(search_reference.to_json).to eq '{}'
      end
    end
  end
end
