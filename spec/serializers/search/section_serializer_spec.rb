describe Search::SectionSerializer do
  subject(:serializer) { described_class.new(section) }

  describe '#to_json' do
    let(:section) { create(:section) }

    let(:pattern) do
      {
        id: section.id,
        numeral: section.numeral,
        title: section.title,
        position: section.position,
        declarable: false,
      }
    end

    it { expect(serializer.to_json).to match_json_expression pattern }
  end
end
