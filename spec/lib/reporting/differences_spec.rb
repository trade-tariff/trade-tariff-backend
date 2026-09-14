RSpec.describe Reporting::Differences do
  describe '.generate' do
    include_context 'with a stubbed reporting bucket'

    let(:report) { instance_double(described_class) }
    let(:workbook) { instance_double('FastExcel::Workbook') }

    before do
      allow(described_class).to receive(:new).and_return(report)
      allow(report).to receive(:generate).and_return(workbook)
    end

    context 'when running in production' do
      before do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
        allow(workbook).to receive(:read_string).and_return('xlsx-bytes')
        described_class.generate
      end

      it 'opens the workbook without a local filename and uploads the serialized workbook' do
        expect(described_class).to have_received(:new).with(nil)
        expect(s3_bucket.client.api_requests).to include(
          hash_including(
            operation_name: :put_object,
            params: hash_including(
              bucket: s3_bucket.name,
              key: /^uk\/reporting\/\d{4}\/\d{2}\/\d{2}\/differences_\d{4}-\d{2}-\d{2}\.xlsx$/,
              body: 'xlsx-bytes',
              content_type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            ),
          ),
        )
      end
    end

    context 'when running in development' do
      before do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('development'))
        described_class.generate
      end

      it 'opens the workbook with a local basename and skips upload' do
        expect(described_class).to have_received(:new).with(File.basename(described_class.send(:object_key)))
        expect(s3_bucket.client.api_requests).to be_empty
      end
    end
  end

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
