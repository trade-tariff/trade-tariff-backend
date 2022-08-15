RSpec.describe Api::V2::RulesOfOrigin::OriginReferenceDocumentSerializer do
  subject(:serializable) { described_class.new(origin_reference_document).serializable_hash }

  let(:origin_reference_document) { build :rules_of_origin_origin_reference_document }

  let :expected do
    {
      data: {
        id: origin_reference_document.id,
        type: :rules_of_origin_origin_reference_document,
        attributes: {
          ord_title: origin_reference_document.ord_title,
          ord_version: origin_reference_document.ord_version,
          ord_date: origin_reference_document.ord_date,
          ord_original: origin_reference_document.ord_original,
        },
      },
    }
  end

  describe '#serializable_hash' do
    it 'matches the expected hash' do
      expect(serializable).to eql expected
    end
  end
end
