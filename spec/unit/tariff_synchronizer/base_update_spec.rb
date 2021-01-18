require 'rails_helper'
require 'tariff_synchronizer'

describe TariffSynchronizer::BaseUpdate do
  include BankHolidaysHelper

  before do
    stub_holidays_gem_between_call
  end

  describe '#file_path' do
    before do
      allow(TariffSynchronizer).to receive(:root_path).and_return('data')
    end

    context 'whe Chief Update' do
      it 'returns the concatenated path of where the file is' do
        chief_update = build(:chief_update, filename: 'hola_mundo.txt')
        expect(chief_update.file_path).to eq('data/chief/hola_mundo.txt')
      end
    end

    context 'whe Taric Update' do
      it 'returns the concatenated path of where the file is' do
        taric_update = build(:taric_update, filename: 'hola_mundo.txt')
        expect(taric_update.file_path).to eq('data/taric/hola_mundo.txt')
      end
    end
  end

  describe '.latest_applied_of_both_kinds' do
    it 'Makes the right sql query' do
      expected_sql = %{SELECT DISTINCT ON ("update_type") "tariff_updates".* FROM "tariff_updates" WHERE ("state" = 'A') ORDER BY "update_type", "issue_date" DESC}
      result = TariffSynchronizer::BaseUpdate.latest_applied_of_both_kinds.sql
      expect(result).to eq(expected_sql)
    end

    it 'returns only one record for each update_type' do
      create_list :chief_update, 2, :applied
      create_list :taric_update, 2, :applied
      result = TariffSynchronizer::BaseUpdate.latest_applied_of_both_kinds.all
      expect(result.size).to eq(2)
    end

    it 'return only the most recen one of each update_type' do
      date = Date.new(2016, 2, 6)
      create :chief_update, :applied, issue_date: date
      create :chief_update, :applied, issue_date: date - 1
      result = TariffSynchronizer::BaseUpdate.latest_applied_of_both_kinds.all
      expect(result.size).to eq(1)
      expect(result.first.issue_date).to eq(date)
    end
  end

  describe '.sync' do
    it 'Calls the download method for each date since the last issue_date to the current date' do
      update = create :chief_update, :missing, issue_date: 1.day.ago

      expect(TariffSynchronizer::ChiefUpdate).to receive(:download).with(update.issue_date)
      expect(TariffSynchronizer::ChiefUpdate).to receive(:download).with(Date.current)
      TariffSynchronizer::ChiefUpdate.sync
    end

    it 'logs and send email about several missing updates in a row' do
      create :chief_update, :missing, issue_date: 1.day.ago
      create :chief_update, :missing, issue_date: 2.days.ago
      create :chief_update, :missing, issue_date: 3.days.ago

      allow(TariffSynchronizer::ChiefUpdate).to receive(:download)
      tariff_synchronizer_logger_listener

      TariffSynchronizer::ChiefUpdate.sync

      expect(@logger.logged(:warn).size).to eq(1)
      expect(@logger.logged(:warn).last).to eq('Missing 3 updates in a row for CHIEF')

      expect(ActionMailer::Base.deliveries).not_to be_empty
      email = ActionMailer::Base.deliveries.last
      expect(email.subject).to include('Missing 3 CHIEF updates in a row')
      expect(email.encoded).to include('Trade Tariff found 3 CHIEF updates in a row to be missing')
    end
  end

  describe '#last_updates_are_missing?' do
    context 'with weekends' do
      before do
        travel_to Date.parse('21-05-2017')
      end

      after do
        travel_back
      end

      let!(:chief_update1) { create :chief_update, :missing, example_date: Date.current }
      let!(:chief_update2) { create :chief_update, example_date: Date.yesterday }

      it 'returns false' do
        expect(described_class.send(:last_updates_are_missing?)).to be_falsey
      end
    end

    context 'without weekends' do
      before do
        travel_to Date.parse('17-05-2017')
      end

      after do
        travel_back
      end

      let!(:chief_update1) { create :chief_update, :missing, example_date: Date.current }
      let!(:chief_update2) { create :chief_update, example_date: Date.yesterday }

      it 'returns true' do
        expect(described_class.send(:last_updates_are_missing?)).to be_truthy
      end
    end
  end
end
