RSpec.describe MaintenanceMode do
  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('MAINTENANCE').and_return maintenance_enabled
  end

  let(:maintenance_enabled) { 'true' }

  describe '.active?' do
    subject { described_class.active? }

    context 'without env var' do
      let(:maintenance_enabled) { nil }

      it { is_expected.to be false }
    end

    context 'with env var' do
      it { is_expected.to be true }
    end

    describe 'bypass' do
      subject { described_class.active? 'success' }

      before do
        allow(ENV).to receive(:[]).with('MAINTENANCE_BYPASS').and_return bypass
      end

      context 'with blank bypass env var' do
        let(:bypass) { '' }

        it { is_expected.to be true }
      end

      context 'with matching bypass param' do
        let(:bypass) { 'success' }

        it { is_expected.to be false }
      end

      context 'without matching bypass param' do
        let(:bypass) { 'somethingdifferent' }

        it { is_expected.to be true }
      end
    end
  end

  describe 'check!' do
    subject(:check) { described_class.check! }

    context 'when active' do
      it { expect { check }.to raise_exception described_class::MaintenanceModeActive }
    end

    context 'when not active' do
      let(:maintenance_enabled) { nil }

      it { is_expected.to be_nil }
    end
  end
end
