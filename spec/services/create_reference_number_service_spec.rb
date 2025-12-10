RSpec.describe CreateReferenceNumberService, type: :service do
  subject(:call) { described_class.new.call }

  describe '#call' do
    it { is_expected.to have_attributes(size: 8) }
    it { expect(call.chars).to all(be_in(described_class::CHARSET)) }
    it { is_expected.not_to match(/[OI]/) }
  end
end
