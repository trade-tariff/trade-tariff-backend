RSpec.describe Subscriptions::Type do
  it 'has the correct associations' do
    t = described_class.association_reflections[:subscriptions]
    expect(t[:type]).to eq(:one_to_many)
  end

  describe '.stop_press' do
    context 'when stop press type does not exist' do
      it 'creates and returns the stop press type' do
        expect(described_class.stop_press.name).to eq Subscriptions::Type::STOP_PRESS
      end
    end

    context 'when the stop press type does exist' do
      it 'returns the stop press type' do
        stop_press = create(:subscription_type, name: Subscriptions::Type::STOP_PRESS, description: 'Stop press email subscription for all stop presses, or particular chapters')
        expect(described_class.stop_press).to eq stop_press
      end
    end
  end
end
