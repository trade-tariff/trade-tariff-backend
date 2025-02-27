RSpec.describe GreenLanesUpdatesPublisher::DataUpdatesFinder do
  subject(:instance) { described_class.new Time.zone.today }

  context 'when there are new measures' do
    before do
      create :measure, trade_movement_code: '1', generating_regulation: create(:base_regulation)
      create :measure, trade_movement_code: '0', generating_regulation: create(:modification_regulation)
    end

    describe '#call' do
      subject { instance.call }

      it { is_expected.to have_attributes(size: 2) }
    end
  end

  context 'when there are expired measures' do
    before do
      create :measure, validity_end_date: Time.zone.today - 1, trade_movement_code: '1', generating_regulation: create(:base_regulation)
      create :measure, trade_movement_code: '1', generating_regulation: create(:base_regulation, validity_end_date: Time.zone.today - 1)
      create :measure, trade_movement_code: '0', generating_regulation: create(:modification_regulation, effective_end_date: Time.zone.today - 1)
    end

    describe '#call' do
      subject { instance.call }

      it { is_expected.to have_attributes(size: 6) }
    end
  end

  context 'when there are updated measures' do
    before do
      create :measure, :with_measure_conditions, trade_movement_code: '1', generating_regulation: create(:base_regulation)
      create :measure, :with_measure_excluded_geographical_area, trade_movement_code: '1', generating_regulation: create(:base_regulation)
      create :measure, :with_additional_code, trade_movement_code: '1', generating_regulation: create(:base_regulation)
    end

    describe '#call' do
      subject { instance.call }

      it { is_expected.to have_attributes(size: 6) }
    end
  end
end
