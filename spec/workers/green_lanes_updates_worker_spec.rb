RSpec.describe GreenLanesUpdatesWorker, type: :worker do
  subject(:worker) { described_class.new }

  let(:measure) { create :measure, trade_movement_code: '1', generating_regulation: create(:base_regulation) }

  before do
    create :identified_measure_type_category_assessment, measure:
  end

  it 'creates CA with identified measure type' do
    worker.perform

    category_assessments = GreenLanes::CategoryAssessment.all.pluck(:value)

    expect(category_assessments).to include(
                                      measure.measure_type_id,
                                      measure.measure_generating_regulation_id,
                                      measure.measure_generating_regulation_role,
    )
  end
end
