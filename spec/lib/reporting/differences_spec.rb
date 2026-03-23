RSpec.describe Reporting::Differences do
  describe '#instrument_report_step' do
    subject(:instrument_step) do
      report.send(:instrument_report_step, 'example_step') { :ok }
    end

    let(:report) { described_class.new }

    before do
      allow(Rails.logger).to receive(:info)
      allow(Rails.logger).to receive(:error)
    end

    it 'supports instrumentation from report instances' do
      expect(instrument_step).to eq(:ok)
    end
  end

  describe '#report_log_attributes' do
    subject(:report_log_attributes) { report.send(:report_log_attributes) }

    let(:report) { described_class.new }

    it 'uses the class report metadata for report instances' do
      expect(report_log_attributes).to include(
        report: described_class.name,
        object_key: described_class.send(:object_key),
      )
    end
  end
end
