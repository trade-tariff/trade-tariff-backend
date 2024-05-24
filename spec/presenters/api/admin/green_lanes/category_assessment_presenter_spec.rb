RSpec.describe Api::Admin::GreenLanes::CategoryAssessmentPresenter do
  subject { described_class.new(category_assessment) }

  let(:category_assessment) { create :category_assessment, :with_green_lanes_measure, :with_exemption }

  it { is_expected.to have_attributes green_lanes_measure_ids: category_assessment.green_lanes_measures.map(&:id) }
  it { is_expected.to have_attributes exemption_ids: category_assessment.exemptions.map(&:id) }
end
