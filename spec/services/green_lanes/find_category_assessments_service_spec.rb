RSpec.describe GreenLanes::FindCategoryAssessmentsService do
  describe '#call' do
    subject(:matches) { described_class.call goods_nomenclature: }

    before do
      GreenLanes::CategoryAssessment.load_from_string json_categorisations

      allow(goods_nomenclature).to receive(:applicable_measures).and_return measures
    end

    let(:goods_nomenclature) { create(:subheading) }

    let(:measures) do
      [
        create(:measure, measure_generating_regulation_id: 'D0000001', measure_type_id: '400'),
        create(:measure, measure_generating_regulation_id: 'D0000002', measure_type_id: '500'),
        create(:measure, measure_generating_regulation_id: 'D0000003', measure_type_id: '713'),
      ]
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

    context 'without origin filter' do
      it { is_expected.to have_attributes length: 4 }
    end

    context 'when geographical_area_id is provided' do
      subject { described_class.call(goods_nomenclature:, geographical_area_id: 'AU') }

      it { is_expected.to have_attributes length: 2 }
    end

    context 'with duplicate measures' do
      let(:measures) do
        [
          create(:measure, measure_generating_regulation_id: 'D0000002', measure_type_id: '500'),
          create(:measure, measure_generating_regulation_id: 'D0000003', measure_type_id: '713'),
          create(:measure, measure_generating_regulation_id: 'D0000003', measure_type_id: '713'),
        ]
      end

      let(:matched_regulation_ids) { matches.map(&:regulation_id) }

      it { is_expected.to have_attributes length: 2 }

      it 'includes expected category assessments' do
        expect(matched_regulation_ids).to match_array %w[D0000002 D0000003]
      end
    end
  end
end
