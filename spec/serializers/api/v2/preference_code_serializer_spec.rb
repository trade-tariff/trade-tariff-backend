RSpec.describe Api::V2::PreferenceCodeSerializer do
  subject(:serializable) { described_class.new(preference_code).serializable_hash }

  let(:preference_code) do
    PreferenceCode.new(code: '100', description: 'Erga Omnes third country duty rates')
  end

  let :expected do
    {
      data: {
        id: '100',
        type: :preference_code,
        attributes: {
          code: '100',
          description: 'Erga Omnes third country duty rates',
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
