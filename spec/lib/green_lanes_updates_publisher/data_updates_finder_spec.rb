RSpec.describe GreenLanesUpdatesPublisher::DataUpdatesFinder do
  subject(:instance) { described_class.new Time.zone.today - 1.day }

  before do
    create :measure, generating_regulation: create(:base_regulation)
    create :measure, generating_regulation: create(:modification_regulation)
  end

  describe '#call' do
    subject { instance.call }

    it { is_expected.to have_attributes(size: 2) }
  end
end
