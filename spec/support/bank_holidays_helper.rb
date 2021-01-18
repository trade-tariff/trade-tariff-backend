module BankHolidaysHelper
  def stub_holidays_gem_between_call
    res = [
      { date: Date.parse('2016-11-30'), name: 'Day 1', regions: [:be_nl] },
      { date: Date.parse('2015-10-07'), name: 'Day 2', regions: [:gb] },
      { date: Date.parse('2016-10-09'), name: 'Day 3', regions: [:gb] },
    ]
    allow(Holidays).to receive(:between).and_return(res)
  end
end
