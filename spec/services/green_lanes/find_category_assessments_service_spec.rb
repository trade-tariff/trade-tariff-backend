RSpec.describe GreenLanes::FindCategoryAssessmentsService do
  describe '#call' do
    subject(:matches) { described_class.call goods_nomenclature: }

    before do
      allow(GreenLanes::CategoryAssessmentJson).to receive(:all).and_return(category_assessments)

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

    let :category_assessments do
      [
        build(:category_assessment_json, regulation_id: 'D0000001',
                                         measure_type_id: '400',
                                         geographical_area_id: 'CH'),
        build(:category_assessment_json, regulation_id: 'D0000001',
                                         measure_type_id: '400',
                                         geographical_area_id: 'AU'),
        build(:category_assessment_json, regulation_id: 'D0000002',
                                         measure_type_id: '500',
                                         geographical_area_id: 'CH'),
        build(:category_assessment_json, regulation_id: 'D0000003',
                                         measure_type_id: '713',
                                         geographical_area_id: '1011'),
      ]
    end

    context 'without origin filter' do
      it { is_expected.to have_attributes length: 4 }

      it { expect(matches[0].measure_ids).to match_array [measures[0].measure_sid] }
      it { expect(matches[1].measure_ids).to match_array [measures[0].measure_sid] }
      it { expect(matches[2].measure_ids).to match_array [measures[1].measure_sid] }
      it { expect(matches[3].measure_ids).to match_array [measures[2].measure_sid] }
    end

    context 'when origin is provided' do
      subject(:matches) { described_class.call(goods_nomenclature:, geographical_area_id: 'AU') }

      it { is_expected.to have_attributes length: 2 }
      it { expect(matches[0].measure_ids).to match_array [measures[0].measure_sid] }
      it { expect(matches[1].measure_ids).to match_array [measures[2].measure_sid] }
    end

    context 'with multiple measures' do
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

      it { expect(matches[0].measure_ids).to match_array [measures[0].measure_sid] }
      it { expect(matches[1].measure_ids).to match_array [measures[1].measure_sid, measures[2].measure_sid] }
    end
  end
end
