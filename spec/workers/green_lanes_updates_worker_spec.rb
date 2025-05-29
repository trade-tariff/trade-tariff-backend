require 'rails_helper'

RSpec.describe GreenLanesUpdatesWorker, type: :worker do
  subject(:worker) { described_class.new }

  let(:measure) { create :measure, trade_movement_code: '1', generating_regulation: create(:base_regulation) }

  before do
    allow(TradeTariffBackend).to receive(:service).and_return 'xi'
    create(:identified_measure_type_category_assessment, measure:).reload
  end

  describe 'run green lanes updates worker' do
    it 'creates CA with identified measure type' do
      worker.perform

      category_assessments = GreenLanes::CategoryAssessment.all.pluck(:measure_type_id, :regulation_id, :regulation_role)

      expect(category_assessments).to include([measure.measure_type_id,
                                               measure.measure_generating_regulation_id,
                                               measure.measure_generating_regulation_role])
    end
  end
end
