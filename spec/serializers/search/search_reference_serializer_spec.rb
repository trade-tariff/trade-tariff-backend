RSpec.describe Search::SearchReferenceSerializer do
  describe '#to_json' do
    context 'when there is a valid referenced object' do
      let(:search_reference) { described_class.new(create(:search_reference)) }
      let(:pattern) do
        {
          title: search_reference.title,
          title_indexed: search_reference.title,
          reference_class: 'Heading',
          reference: {
            class: 'Heading',
          }.ignore_extra_keys!,
        }
      end

      it 'returns rendered referenced entity as json' do
        expect(search_reference.to_json).to match_json_expression pattern
      end
    end

    context 'when there is no valid referenced object' do
      let(:search_reference) { described_class.new(create(:search_reference, referenced: nil)) }

      it 'returns blank json hash' do
        expect(search_reference.to_json).to eq '{}'
      end
    end
  end
end
