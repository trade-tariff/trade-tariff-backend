RSpec.describe Api::V2::GreenLanes::CategoryAssessmentPresenter do
  subject { described_class.new(category_assessment, measures) }

  let :category_assessment do
    GreenLanes::CategoryAssessment.new(category: 1,
                                       regulation_id: 'D0000001',
                                       measure_type_id: '400',
                                       geographical_area_id: 'CH')
  end

  let :measures do
    create_list(:measure, 1, measure_generating_regulation_id: 'D0000001',
                             measure_type_id: '400')
  end

  it { is_expected.to have_attributes id: category_assessment.id }
  it { is_expected.to have_attributes measures: }
  it { is_expected.to have_attributes measure_ids: measures.map(&:measure_sid) }
end
