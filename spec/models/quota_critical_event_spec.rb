RSpec.describe QuotaCriticalEvent do
  describe '.status' do
    subject(:status) { described_class.status }

    it { is_expected.to eq('Critical') }
  end

  describe '#active?' do
    subject(:event) { build(:quota_critical_event, critical_state:) }

    context 'when the critical event is active' do
      let(:critical_state) { 'Y' }

      it { is_expected.to be_active }
    end

    context 'when the critical event is inactive' do
      let(:critical_state) { 'N' }

      it { is_expected.not_to be_active }
    end
  end
end
