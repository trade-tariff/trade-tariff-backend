require 'rails_helper'

RSpec.describe ExchangeRatesHelper, type: :helper do
  describe '#next_month_year' do
    it 'returns the next month\'s year' do
      date = Date.new(2023, 12, 1)
      next_year = helper.next_month_year(date)
      expect(next_year).to eq(2024)
    end

    it 'returns the current year if the next month is in the same year' do
      date = Date.new(2023, 11, 1)
      next_year = helper.next_month_year(date)
      expect(next_year).to eq(2023)
    end
  end

  describe '#next_month' do
    it 'returns the next month' do
      date = Date.new(2023, 7, 1)
      next_month = helper.next_month(date)
      expect(next_month).to eq(8)
    end
  end
end
