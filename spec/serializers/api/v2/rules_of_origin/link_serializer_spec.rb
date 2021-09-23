RSpec.describe Api::V2::RulesOfOrigin::LinkSerializer do
  subject(:serializable) { described_class.new(link).serializable_hash }

  let(:link) { build :rules_of_origin_link }

  let :expected do
    {
      data: {
        id: link.id,
        type: :rules_of_origin_link,
        attributes: {
          text: link.text,
          url: link.url,
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
