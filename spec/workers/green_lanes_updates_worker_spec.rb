RSpec.describe GreenLanesUpdatesWorker, type: :worker do
  subject(:worker) { described_class.new }

  let!(:measure) { create :measure, trade_movement_code: '1', generating_regulation: create(:base_regulation) }
  let!(:ca) { create :identified_measure_type_category_assessment, measure: measure }

  before do
    allow(TradeTariffBackend).to receive(:service).and_return 'xi'
  end

  describe 'run green lanes updates worker' do
    before { worker.perform }

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

  describe '#create_automated_ca' do
    def build_created_update(measure)
      GreenLanesUpdatesPublisher::GreenLanesUpdate.new(
        measure.measure_generating_regulation_id,
        measure.measure_generating_regulation_role,
        measure.measure_type_id,
        ::GreenLanes::UpdateNotification::NotificationStatus::CREATED,
      )
    end

    it 'creates a category assessment for each created update with an identified CA' do
      first_measure = create(:measure, trade_movement_code: '1', generating_regulation: create(:base_regulation))
      second_measure = create(:measure, trade_movement_code: '1', generating_regulation: create(:base_regulation))
      first_identified = create(:identified_measure_type_category_assessment, measure: first_measure)
      second_identified = create(:identified_measure_type_category_assessment, measure: second_measure)
      updates = [build_created_update(first_measure), build_created_update(second_measure)]

      expect { worker.send(:create_automated_ca, updates) }
        .to change(GreenLanes::CategoryAssessment, :count).by(2)

      expect(updates.map(&:status)).to all(eq(::GreenLanes::UpdateNotification::NotificationStatus::CA_CREATED))
      expect(updates.map(&:theme_id)).to contain_exactly(first_identified.theme_id, second_identified.theme_id)
    end

    it 'skips updates that already have a category assessment' do
      first_measure = create(:measure, trade_movement_code: '1', generating_regulation: create(:base_regulation))
      second_measure = create(:measure, trade_movement_code: '1', generating_regulation: create(:base_regulation))
      create(:identified_measure_type_category_assessment, measure: first_measure)
      create(:identified_measure_type_category_assessment, measure: second_measure)
      create(:category_assessment, measure: first_measure)
      updates = [build_created_update(first_measure), build_created_update(second_measure)]

      expect { worker.send(:create_automated_ca, updates) }
        .to change(GreenLanes::CategoryAssessment, :count).by(1)

      expect(updates.map(&:status)).to contain_exactly(
        ::GreenLanes::UpdateNotification::NotificationStatus::CREATED,
        ::GreenLanes::UpdateNotification::NotificationStatus::CA_CREATED,
      )
    end
  end
end
