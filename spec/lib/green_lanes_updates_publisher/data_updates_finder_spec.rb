RSpec.describe GreenLanesUpdatesPublisher::DataUpdatesFinder do
  subject(:instance) { described_class.new Time.zone.today - 2.day }

  before do
    create :measure, trade_movement_code: '1', generating_regulation: create(:base_regulation)
    create :measure, trade_movement_code: '0', generating_regulation: create(:modification_regulation)
  end

  describe '#call' do
    subject { instance.call }

    it { is_expected.to have_attributes(size: 2) }
  end
end
