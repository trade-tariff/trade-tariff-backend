RSpec.describe Reporting::CategoryAssessments do
  describe '.generate' do
    include_context 'with a stubbed reporting bucket'

    let(:serialized_assessments) { instance_double(Api::V2::GreenLanes::CategoryAssessmentSerializer, serializable_hash: { data: [] }) }
    let(:category_assessment) { instance_double(GreenLanes::CategoryAssessment) }

    before do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
      allow(TradeTariffBackend).to receive(:xi?).and_return(true)
      allow(described_class).to receive_messages(
        category_assessments: [category_assessment],
        serialized_assessments:,
      )
    end

    it 'writes a ZIP file to the reporting bucket' do
      described_class.generate

      expect(s3_bucket.client.api_requests).to include(
        hash_including(
          operation_name: :put_object,
          params: hash_including(
            bucket: s3_bucket.name,
            key: /^.*\/category_assessments_.*\.zip$/,
            body: instance_of(String),
            content_type: 'application/zip',
          ),
        ),
      )
    end
  end
end
