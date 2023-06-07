RSpec.describe TimeMachine do
  let!(:commodity1) do
    create :commodity, validity_start_date: Time.zone.now.ago(1.day),
                       validity_end_date: Time.zone.now.in(1.day)
  end
  let!(:commodity2) do
    create :commodity, validity_start_date: Time.zone.now.ago(20.days),
                       validity_end_date: Time.zone.now.ago(10.days)
  end

  describe '.at' do
    it 'sets date to current date if argument is blank' do
      described_class.at(nil) do
        expect(Commodity.actual.all).to     include commodity1
        expect(Commodity.actual.all).not_to include commodity2
      end
    end

    it 'sets date to current date if argument is errorenous' do
      described_class.at('#&$*(#)') do
        expect(Commodity.actual.all).to     include commodity1
        expect(Commodity.actual.all).not_to include commodity2
      end
    end

    it 'parses and sets valid date from argument' do
      described_class.at(Time.zone.now.ago(15.days).to_s) do
        expect(Commodity.actual.all).not_to include commodity1
        expect(Commodity.actual.all).to     include commodity2
      end
    end
  end

  describe '.now' do
    it 'sets date to current date' do
      described_class.now do
        expect(Commodity.actual.all).to     include commodity1
        expect(Commodity.actual.all).not_to include commodity2
      end
    end
  end

  describe '.no_time_machine' do
    it { described_class.no_time_machine { expect(Commodity.point_in_time).to be_nil } }
  end
end
