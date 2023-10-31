require 'rails_helper'

RSpec.describe ReportsMailer, type: :mailer do
  describe '#differences' do
    subject(:mail) { described_class.differences(report).tap(&:deliver_now) }

    before do
      allow(Reporting::Commodities).to receive(:get_uk_today).and_return('')
      allow(Reporting::Commodities).to receive(:get_xi_today).and_return('')
      allow(Reporting::SupplementaryUnits).to receive(:get_uk_today).and_return('')
      allow(Reporting::SupplementaryUnits).to receive(:get_xi_today).and_return('')
    end

    let(:report) { Reporting::Differences.new }

    it { expect(mail.subject).to eq('[HMRC Online Trade Tariff Support] UK tariff - potential issues report 2023-10-31') }
    it { expect(mail.from).to eq(['no-reply@example.com']) }
    it { expect(mail.to).to eq(['differences@example.com']) }
    it { expect(mail.bcc).to eq(['user@example.com']) }
  end
end
