RSpec.describe TariffSynchronizer::TaricUpdate do
  let(:example_date) { Date.new(2010, 1, 1) }

  it_behaves_like 'Base Update'

  describe '.sync' do
    before do
      allow(TariffSynchronizer::TaricUpdateDownloader).to receive(:new).and_return(instance_double(TariffSynchronizer::TaricUpdateDownloader, perform: nil))
    end

    it 'calls the downloader with the correct args' do
      create :taric_update, :applied, issue_date: 1.day.ago.to_date

      described_class.sync(initial_date: 20.days.ago.to_date)

      (20.days.ago.to_date..Time.zone.today).each do |download_date|
        expect(TariffSynchronizer::TaricUpdateDownloader).to have_received(:new).with(download_date)
      end
    end
  end

  describe '.sync_patched' do
    before do
      allow(TariffSynchronizer::TaricUpdateDownloaderPatched).to receive(:new).and_return(instance_double(TariffSynchronizer::TaricUpdateDownloaderPatched, perform: nil))
    end

    it 'calls the downloader with the correct args' do
      create :taric_update, :applied, issue_date: 1.day.ago

      described_class.sync_patched

      expect(TariffSynchronizer::TaricUpdateDownloaderPatched).to have_received(:new).with(an_instance_of(described_class)).once
    end
  end

  describe '#import!' do
    let(:taric_update) { create :taric_update }
    let(:taric_importer) { instance_double(TaricImporter) }

    before do
      allow(TaricImporter).to receive(:new).with(taric_update).and_return(taric_importer)
      allow(taric_importer).to receive(:import)
      allow(taric_update).to receive(:file_path).and_return('spec/fixtures/taric_samples/insert_record.xml')
    end

    it 'calls the TaricImporter import method' do
      taric_update.import!
      expect(taric_importer).to have_received(:import)
    end

    it 'marks the Taric update as applied' do
      taric_update.import!
      expect(taric_update.reload).to be_applied
    end

    it 'emits a file_import_completed instrumentation event' do
      allow(TariffSynchronizer::Instrumentation).to receive(:file_import_completed)

      taric_update.import!

      expect(TariffSynchronizer::Instrumentation).to have_received(:file_import_completed).with(
        hash_including(filename: taric_update.filename),
      )
    end
  end

  describe '.correct_filename_sequence?' do
    subject(:taric_update) { described_class }

    context 'when there are updates with an unbroken sequence' do
      before do
        create(:taric_update, :missing, example_date: Date.parse('2021-12-04'), sequence_number: 'foo')
        create(:taric_update, :pending, example_date: Date.parse('2021-12-03'), sequence_number: '202')
        create(:taric_update, :applied, example_date: Date.parse('2021-12-02'), sequence_number: '201')
        create(:taric_update, :applied, example_date: Date.parse('2021-12-01'), sequence_number: '200')
      end

      it { is_expected.to be_correct_filename_sequence }
    end

    context 'when there are updates with a broken sequence' do
      before do
        create(:taric_update, :pending, example_date: Date.parse('2021-12-03'), sequence_number: '203')
        create(:taric_update, :applied, example_date: Date.parse('2021-12-02'), sequence_number: '202')
        create(:taric_update, :applied, example_date: Date.parse('2021-12-01'), sequence_number: '200')
      end

      it { is_expected.not_to be_correct_filename_sequence }
    end

    context 'when there are no updates' do
      it { is_expected.to be_correct_filename_sequence }
    end
  end

  describe '.correct_sequence_pair?' do
    subject(:correct_sequence_pair) { described_class.correct_sequence_pair?(pending_update, applied_update) }

    let(:pending_update) { create(:taric_update, :pending, example_date: pending_date, sequence_number: pending_sequence_number) }
    let(:applied_update) { create(:taric_update, :applied, example_date: Date.parse('2021-12-01'), sequence_number: '002') }

    context 'when the pending year is the same and the pending sequence is the next valid sequence' do
      let(:pending_date) { Date.parse('2021-12-02') } # Same year
      let(:pending_sequence_number) { '003' } # Correct sequence

      it { is_expected.to be_truthy }
    end

    context 'when the pending year is the same and the pending sequence is NOT the next valid sequence' do
      let(:pending_date) { Date.parse('2021-12-02') } # Same year
      let(:pending_sequence_number) { '004' } # Incorrect sequence

      it { is_expected.to be_falsey }
    end

    context 'when the pending year is the following year and the pending sequence is 001' do
      let(:pending_date) { Date.parse('2022-12-02') } # Following year
      let(:pending_sequence_number) { '001' } # Correct sequence

      it { is_expected.to be_truthy }
    end

    context 'when the pending year is the following year and the pending sequence is NOT the next valid sequence' do
      let(:pending_date) { Date.parse('2022-12-02') } # Following year
      let(:pending_sequence_number) { '002' } # Incorrect sequence

      it { is_expected.to be_falsey }
    end
  end

  describe '#filename_sequence' do
    subject(:taric_update) { create(:taric_update, filename:) }

    let(:filename) { '2021-12-30_TGB21257.xml' }

    it 'returns the correct named captures' do
      expect(taric_update.filename_sequence.named_captures).to eq('year' => '21', 'sequence' => '257', 'url_filename' => 'TGB21257.xml')
    end
  end

  describe '#next_update_sequence_url_filename' do
    subject(:next_update_sequence_url_filename) { taric_update.next_update_sequence_url_filename }

    let(:taric_update) { create(:taric_update, filename: '2021-12-30_TGB21257.xml', issue_date:) }

    context 'when the next issue date is the same year' do
      let(:issue_date) { Date.parse('2021-12-30') }

      it { is_expected.to eq('TGB21258.xml') }
    end

    context 'when the next issue date is a new year' do
      let(:issue_date) { Date.parse('2021-12-31') }

      it { is_expected.to eq('TGB22001.xml') }
    end
  end

  describe '#next_update_sequence_update_filename' do
    subject(:next_update_sequence_update_filename) { taric_update.next_update_sequence_update_filename }

    let(:taric_update) { create(:taric_update, filename: '2021-12-30_TGB21257.xml', issue_date:) }

    context 'when the next issue date is the same year' do
      let(:issue_date) { Date.parse('2021-12-30') }

      it { is_expected.to eq('2021-12-31_TGB21258.xml') }
    end

    context 'when the next issue date is a new year' do
      let(:issue_date) { Date.parse('2021-12-31') }

      it { is_expected.to eq('2022-01-01_TGB22001.xml') }
    end
  end

  describe '#next_update' do
    subject(:next_update) { build(:taric_update, :applied, example_date: Date.parse('2022-08-25')).next_update }

    it { is_expected.to have_attributes(issue_date: Date.parse('2022-08-26'), filename: '2022-08-26_TGB22238.xml') }
  end

  describe '#next_rollover_update' do
    subject(:next_rollover_update) { build(:taric_update, :applied, example_date: Date.parse('2022-08-25')).next_rollover_update }

    it { is_expected.to have_attributes(issue_date: Date.parse('2023-01-01'), filename: '2023-01-01_TGB23001.xml') }
  end

  describe '#url_filename' do
    subject(:url_filename) { create(:taric_update, :pending, example_date: Date.parse('2021-12-03'), sequence_number: '203').url_filename }

    it { is_expected.to eq('TGB21203.xml') }
  end

  describe '.applicable_update' do
    subject(:applicable_update) { described_class.applicable_update.as_json }

    context 'when there is an unbroken sequence of applied and pending updates' do
      before do
        create(:taric_update, :pending, example_date: Date.parse('2021-12-03'), sequence_number: '203')
        create(:taric_update, :applied, example_date: Date.parse('2021-12-02'), sequence_number: '202')
      end

      let(:expected_update) do
        { 'filename' => '2021-12-04_TGB21204.xml', 'issue_date' => '2021-12-04' }
      end

      it { is_expected.to eq(expected_update) }
    end

    context 'when there is an unbroken sequence of applied updates' do
      before do
        create(:taric_update, :applied, example_date: Date.parse('2021-12-03'), sequence_number: '203')
        create(:taric_update, :applied, example_date: Date.parse('2021-12-02'), sequence_number: '202')
      end

      let(:expected_update) do
        { 'filename' => '2021-12-04_TGB21204.xml', 'issue_date' => '2021-12-04' }
      end

      it { is_expected.to eq(expected_update) }
    end

    context 'when there are broken sequence updates' do
      before do
        create(:taric_update, :pending, example_date: Date.parse('2021-12-03'), sequence_number: '203')
        create(:taric_update, :applied, example_date: Date.parse('2021-12-02'), sequence_number: '201')
      end

      it { is_expected.to be_nil }
    end

    context 'when there are no updates' do
      it { is_expected.to be_nil }
    end
  end
end
