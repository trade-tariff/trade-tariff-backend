class ExchangeRatesMailer < ApplicationMailer
  default to: TradeTariffBackend.management_email

  attr_reader :date

  def monthly_files(date)
    @date = date
    @month_and_year = date.strftime('%B %Y')
    @csv_hmrc = ExchangeRateFile.where(
      type: 'monthly_csv_hmrc',
      period_month: date.month,
      period_year: date.year,
    ).take

    mail subject: "#{@month_and_year} Exchange Rate Files (monthly)"
  end
end
