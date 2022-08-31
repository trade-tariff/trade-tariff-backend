require 'rails_helper'

RSpec.describe ImportTradeSummary do
  describe 'attributes' do
    it { is_expected.to respond_to :basic_third_country_duty }
    it { is_expected.to respond_to :preferential_tariff_duty }
    it { is_expected.to respond_to :preferential_quota_duty }
  end

  describe '#id' do
    it 'is not nil' do
      import_trade_summary = ImportTradeSummary.new

      expect(import_trade_summary).not_to be_nil
    end
  end

  describe '#basic_third_country_duty' do
    let(:import_measures) { [create(:measure, :third_country_overview)] }

    it 'is present' do
      import_trade_summary = ImportTradeSummary.build(import_measures)

      expect(import_trade_summary.basic_third_country_duty).not_to be_nil
    end
  end

  describe '#preferential_tariff_duty' do
    let(:import_measures) { [create(:measure, :tariff_preference)] }

    it 'is present' do
      import_trade_summary = ImportTradeSummary.build(import_measures)

      expect(import_trade_summary.preferential_tariff_duty).not_to be_nil
    end
  end

  describe '#preferential_quota_duty' do
    let(:import_measures) { [create(:measure, :preferential_quota)] }

    it 'return something' do
      import_trade_summary = ImportTradeSummary.build(import_measures)

      expect(import_trade_summary.preferential_quota_duty).not_to be_nil
    end
  end
end
