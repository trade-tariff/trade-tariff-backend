RSpec.describe GreenLanes::FindCategoryAssessmentsService do
  describe '#call' do
    subject(:service) { described_class }

    before do
      GreenLanes::CategoryAssessment.load_from_string json_categorisations

      allow(subheading).to receive(:applicable_measures).and_return measures
    end

    let(:subheading) { create(:subheading) }

    let(:measures) do
      [create(:measure, measure_generating_regulation_id: 'D0000001', measure_type_id: '400'),
       create(:measure, measure_generating_regulation_id: 'D0000002', measure_type_id: '500'),
       create(:measure, measure_generating_regulation_id: 'D0000003', measure_type_id: '713')]
    end

    let(:json_categorisations) do
      [{
        "category": '1',
        "regulation_id": 'D0000001',
        "measure_type_id": '400',
        "geographical_area_id": 'CH',
      },
       {
         "category": '2',
         "regulation_id": 'D0000001',
         "measure_type_id": '400',
         "geographical_area_id": 'AU',
       },
       {
         "category": '1',
         "regulation_id": 'D0000002',
         "measure_type_id": '500',
         "geographical_area_id": 'CH',
       },
       {
         "category": '2',
         "regulation_id": 'D0000003',
         "measure_type_id": '713',
         "geographical_area_id": '1011', # Erga Omnes
       }].to_json
    end

    it 'returns categorisations based on applicable measures' do
      result = service.call(goods_nomenclature: subheading)

      expect(result).to have_attributes length: 4
    end

    context 'when origin is provided' do
      it 'filter categorisations based on origin' do
        result = service.call(goods_nomenclature: subheading, origin: 'AU')

        expect(result).to have_attributes length: 2
      end
    end
  end
end
