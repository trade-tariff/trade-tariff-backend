RSpec.describe MeasurePartialTemporaryStop do
  let(:measure_partial_temporary_stop) { build :measure_partial_temporary_stop }

  describe '#regulation_id' do
    it {
      expect(measure_partial_temporary_stop.regulation_id)
      .to eql measure_partial_temporary_stop.partial_temporary_stop_regulation_id
    }
  end

  describe '#role' do
    it { expect(measure_partial_temporary_stop.role).to be_nil }
  end
end
