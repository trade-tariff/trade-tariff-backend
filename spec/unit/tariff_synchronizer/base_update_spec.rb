RSpec.describe TariffSynchronizer::BaseUpdate do
  include BankHolidaysHelper

  before do
    stub_holidays_gem_between_call
  end

  let(:today) { Time.zone.today }
  let(:yesterday) { Time.zone.yesterday }

  describe '#file_path' do
    before do
      allow(TariffSynchronizer).to receive(:root_path).and_return('data')
    end

    context 'when Taric Update' do
      it 'returns the concatenated path of where the file is' do
        taric_update = build(:taric_update, filename: 'hola_mundo.txt')
        expect(taric_update.file_path).to eq('data/taric/hola_mundo.txt')
      end
    end
  end

  describe '.latest_applied_of_both_kinds' do
    it 'Makes the right sql query' do
      expected_sql = %{SELECT DISTINCT ON ("update_type") "tariff_updates".* FROM "tariff_updates" WHERE (("update_type" != 'TariffSynchronizer::ChiefUpdate') AND ("state" = 'A')) ORDER BY "update_type", "issue_date" DESC}
      expect(described_class.latest_applied_of_both_kinds.sql).to eq(expected_sql)
    end

    it 'returns only one record for each update_type' do
      create_list :taric_update, 2, :applied
      result = described_class.latest_applied_of_both_kinds.all
      expect(result.size).to eq(1)
    end

    it 'return only the most recen one of each update_type' do
      date = Date.new(2016, 2, 6)
      create :taric_update, :applied, issue_date: date
      create :taric_update, :applied, issue_date: date
      result = described_class.latest_applied_of_both_kinds.all
      expect(result.size).to eq(1)
      expect(result.first.issue_date).to eq(date)
    end
  end

  describe '.applicable_download_date_range' do
    shared_examples_for 'an applicable download date range' do |update_factory|
      let(:today) { Time.zone.today }
      let(:pending_issue_date) { today - 21.days }
      let(:applied_issue_date) { today - 22.days }
      let(:failed_issue_date) { today - 23.days }

      context 'when choosing a pending update older than the default download from date' do
        before do
          create(update_factory, :pending, issue_date: pending_issue_date)
          create(update_factory, :applied, issue_date: applied_issue_date)
          create(update_factory, :failed, issue_date: failed_issue_date)
        end

        it { is_expected.to eq(pending_issue_date..today) }
      end

      context 'when choosing a applied update older than the default download from date' do
        before do
          create(update_factory, :applied, issue_date: applied_issue_date)
          create(update_factory, :failed, issue_date: failed_issue_date)
        end

        it { is_expected.to eq(applied_issue_date..today) }
      end

      context 'when choosing a failed update older than the default download from date' do
        before do
          create(update_factory, :failed, issue_date: failed_issue_date)
        end

        it { is_expected.to eq(failed_issue_date..today) }
      end

      context 'when there is an update issued 20 days ago or less' do
        let(:pending_issue_date) { today - 20.days }

        before do
          create(update_factory, :pending, issue_date: pending_issue_date)
        end

        it { is_expected.to eq(pending_issue_date..today) }
      end

      context 'when there are no updates yet' do
        it { is_expected.to eq(initial_date..today) }
      end
    end

    it_behaves_like 'an applicable download date range', :taric_update do
      subject(:applicable_download_date_range) { TariffSynchronizer::TaricUpdate.applicable_download_date_range }

      let(:initial_date) { Date.new(2012, 6, 6) }
    end

    it_behaves_like 'an applicable download date range', :cds_update do
      subject(:applicable_download_date_range) { TariffSynchronizer::CdsUpdate.applicable_download_date_range }

      let(:initial_date) { Date.new(2020, 9, 1) }
    end
  end

  describe '.sync' do
    it 'calls the download method for each date for the last 20 days to the current date' do
      create :cds_update, :applied, issue_date: 1.day.ago

      (20.days.ago.to_date..Date.current).each do |download_date|
        expect(TariffSynchronizer::CdsUpdateDownloader).to receive(:new).with(download_date).and_return(instance_double('TariffSynchronizer::CdsUpdateDownloader', perform: nil))
      end

      TariffSynchronizer::CdsUpdate.sync
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

      let!(:update1) { create :taric_update, :missing, example_date: Date.current }
      let!(:update2) { create :taric_update, example_date: Date.yesterday }

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

      let!(:update1) { create :taric_update, :missing, example_date: Date.current }
      let!(:update2) { create :taric_update, example_date: Date.yesterday }

      it 'returns true' do
        expect(described_class.send(:last_updates_are_missing?)).to be_truthy
      end
    end
  end

  describe '.oldest_pending' do
    subject(:oldest_pending) { described_class.oldest_pending }

    context 'when there are updates' do
      before do
        create(:cds_update, :pending, issue_date:  yesterday) # Target
        create(:cds_update, :pending, issue_date:  today) # Control
        create(:cds_update, :failed, issue_date: yesterday) # Control
        create(:cds_update, :applied, issue_date:  yesterday) # Control
        create(:cds_update, :missing, issue_date:  yesterday) # Control
      end

      it { is_expected.to have_attributes(state: 'P', issue_date: yesterday) }
    end

    context 'when there are no updates' do
      it { is_expected.to be_nil }
    end
  end

  describe '.most_recent_pending' do
    subject(:most_recent_pending) { described_class.most_recent_pending }

    context 'when there are updates' do
      before do
        create(:cds_update, :pending, issue_date:  today) # Target
        create(:cds_update, :pending, issue_date:  yesterday) # Control
        create(:cds_update, :failed, issue_date: today) # Control
        create(:cds_update, :missing, issue_date:  today) # Control
        create(:cds_update, :applied, issue_date:  today) # Control
      end

      it { is_expected.to have_attributes(state: 'P', issue_date: today) }
    end

    context 'when there are no updates' do
      it { is_expected.to be_nil }
    end
  end

  describe '.most_recent_applied' do
    subject(:most_recent_applied) { described_class.most_recent_applied }

    context 'when there are updates' do
      before do
        create(:cds_update, :applied, issue_date:  today) # Target
        create(:cds_update, :applied, issue_date:  yesterday) # Control
        create(:cds_update, :failed, issue_date: today) # Control
        create(:cds_update, :missing, issue_date:  today) # Control
        create(:cds_update, :pending, issue_date:  today) # Control
      end

      it { is_expected.to have_attributes(state: 'A', issue_date: today) }
    end

    context 'when there are no updates' do
      it { is_expected.to be_nil }
    end
  end

  describe '.most_recent_failed' do
    subject(:most_recent_failed) { described_class.most_recent_failed }

    context 'when there are updates' do
      before do
        create(:cds_update, :failed, issue_date: today) # Target
        create(:cds_update, :failed, issue_date: yesterday) # Control
        create(:cds_update, :applied, issue_date:  today) # Control
        create(:cds_update, :applied, issue_date:  yesterday) # Control
        create(:cds_update, :missing, issue_date:  today) # Control
        create(:cds_update, :pending, issue_date:  today) # Control
      end

      it { is_expected.to have_attributes(state: 'F', issue_date: today) }
    end

    context 'when there are no updates' do
      it { is_expected.to be_nil }
    end
  end
end
