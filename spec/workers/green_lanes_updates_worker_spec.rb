RSpec.describe GreenLanesUpdatesWorker, type: :worker do
  subject(:worker) { described_class.new }

  let!(:measure) { create :measure, trade_movement_code: '1', generating_regulation: create(:base_regulation) }
  let!(:ca) { create :identified_measure_type_category_assessment, measure: measure }

  before do
    allow(TradeTariffBackend).to receive(:service).and_return 'xi'
    worker.perform
  end

  describe 'run green lanes updates worker' do
    it 'creates CA with identified measure type' do
      category_assessments = GreenLanes::CategoryAssessment.all.pluck(:measure_type_id, :regulation_id, :regulation_role)

      expect(category_assessments).to include([measure.measure_type_id,
                                               measure.measure_generating_regulation_id,
                                               measure.measure_generating_regulation_role])
    end

    it 'update notification status and and theme id' do
      notification = GreenLanes::UpdateNotification.all.pluck(:measure_type_id, :regulation_id, :regulation_role,
                                                              :status, :theme_id)

      expect(notification).to include([measure.measure_type_id,
                                       measure.measure_generating_regulation_id,
                                       measure.measure_generating_regulation_role,
                                       ::GreenLanes::UpdateNotification::NotificationStatus::CA_CREATED,
                                       ca.theme_id])
    end
  end

  describe 'run green lanes updates worker with existing category assessment' do
    it 'does not create a new CA' do
      create(:category_assessment, measure:)

      worker.perform

      notification = GreenLanes::UpdateNotification.all.pluck(:measure_type_id, :regulation_id, :regulation_role,
                                                              :status, :theme_id)

      expect(notification).to include([measure.measure_type_id,
                                       measure.measure_generating_regulation_id,
                                       measure.measure_generating_regulation_role,
                                       ::GreenLanes::UpdateNotification::NotificationStatus::CREATED,
                                       nil])
    end
  end
end
