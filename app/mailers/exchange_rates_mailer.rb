class ExchangeRatesMailer < ApplicationMailer
  include ExchangeRatesHelper

  default to: TradeTariffBackend.management_email

  def monthly_files
    @month_and_year = date.next_month.strftime('%B %Y')
    @csv_hmrc = ExchangeRateFile.where(type: 'monthly_csv_hmrc', period_month: month, period_year: year).take
    @xml = ExchangeRateFile.where(type: 'monthly_xml', period_month: month, period_year: year).take

    mail subject: "#{@month_and_year} Exchange Rate Files (monthly)"
  end

  private

  def date
    @date ||= Time.zone.today
  end

  def year
    @year ||= next_month_year(date)
  end

  def month
    @month ||= next_month(date)
  end
end