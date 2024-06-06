RSpec.describe Api::Admin::GreenLanes::ExemptionSerializer do
  subject(:serialized) do
    described_class.new(exemption).serializable_hash
  end

  let(:exemption) { create :green_lanes_exemption }

  let :expected do
    {
      data: {
        id: exemption.id.to_s,
        type: :green_lanes_exemption,
        attributes: {
          code: exemption.code,
          description: exemption.description,
        },
      },
    }
  end

  describe '#serializable_hash' do
    it 'matches the expected hash' do
      expect(serialized).to eq(expected)
    end
  end
end
