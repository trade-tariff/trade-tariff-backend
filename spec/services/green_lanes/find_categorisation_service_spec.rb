RSpec.describe GreenLanes::FindCategoryAssessmentsService do
  describe '#find_possible_categorisations' do
    subject(:service) { described_class.new }

    before do
      GreenLanes::CategoryAssessment.load_from_string json_string
    end

    let(:json_string) do
      '[{
          "category": "1",
          "regulation_id": "D0000001",
          "measure_type_id": "400",
          "geographical_area": "1000"
        },
        {
          "category": "2",
          "regulation_id": "D0000001",
          "measure_type_id": "400",
          "geographical_area": "2000"
        },
        {
          "category": "1",
          "regulation_id": "D0000002",
          "measure_type_id": "500",
          "geographical_area": "1000"
        }]'
    end

    it 'returns categorisations based on applicable measures' do
      measure1 = create(:measure, measure_generating_regulation_id: 'D0000001', measure_type_id: '400')
      measure2 = create(:measure, measure_generating_regulation_id: 'D0000002', measure_type_id: '500')
      subheading = create(:subheading)

      allow(subheading).to receive(:applicable_measures).and_return [measure1, measure2]

      result = service.call(subheading)

      expect(result).to have_attributes length: 3
    end
  end
end
