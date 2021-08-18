
describe BankHolidays do
  include BankHolidaysHelper

  before do
    stub_holidays_gem_between_call
  end

  describe '.last(n)' do
    it 'returns last N halidays' do
      expect(described_class.last(2).length).to eq(2)
    end

    it 'returns Array of records' do
      expect(described_class.last(2)).to be_a(Array)
    end

    it 'returns max date less or equal Date.current' do
      expect(described_class.last(3).last).to be <= Date.current
    end

    it 'returns Date type records' do
      expect(described_class.last(2)[0]).to be_a(Date)
    end

    it 'invokes weekends checker method' do
      expect(described_class).to receive(:weekends).with(2)
      described_class.last(2)
    end

    it 'invokes holidays checker method' do
      expect(described_class).to receive(:holidays).with(2)
      described_class.last(2)
    end

    context 'without weekends' do
      before do
        travel_to Date.parse('17-05-2017')
      end

      after do
        travel_back
      end

      it 'orders holidays asc' do
        res = described_class.last(3)
        # see stub_holidays_gem_between_call example
        expect(res[0]).to eq(Date.parse('2015-10-07'))
        expect(res[2]).to eq(Date.parse('2016-11-30'))
      end
    end

    context 'with weekends' do
      before do
        travel_to Date.parse('22-05-2017')
      end

      after do
        travel_back
      end

      it 'orders holidays and weekends asc' do
        res = described_class.last(3)
        # see stub_holidays_gem_between_call example
        expect(res[0]).to eq(Date.parse('2016-11-30'))
        expect(res[1]).to eq(Date.parse('2017-05-20'))
        expect(res[2]).to eq(Date.parse('2017-05-21'))
      end
    end
  end
end
