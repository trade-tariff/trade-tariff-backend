RSpec.describe MeasurePartialTemporaryStop do
  let(:measure_partial_temporary_stop) { build :measure_partial_temporary_stop }

  describe '#regulation_id' do
    it {
      expect(measure_partial_temporary_stop.regulation_id)
      .to eql measure_partial_temporary_stop.partial_temporary_stop_regulation_id
    }
  end

  describe '#effective_end_date' do
    let(:measure_partial_temporary_stop) { build :measure_partial_temporary_stop, validity_end_date: Time.zone.today }

    it 'is an alias for validity_end_date' do
      expect(measure_partial_temporary_stop.effective_end_date).to eq measure_partial_temporary_stop.validity_end_date.to_date
    end
  end

  describe '#effective_start_date' do
    it 'is an alias for validity_start_date' do
      expect(measure_partial_temporary_stop.effective_start_date).to eq measure_partial_temporary_stop.validity_start_date.to_date
    end
  end

  describe '#role' do
    it { expect(measure_partial_temporary_stop.role).to be_nil }
  end
end
