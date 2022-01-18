RSpec.describe TariffSynchronizer::TaricUpdate do
  let(:example_date) { Date.new(2010, 1, 1) }

  it_behaves_like 'Base Update'

  describe '.download' do
    it 'calls TaricUpdateDownloader perform for a TARIC update' do
      downlader = instance_double('TariffSynchronizer::TaricUpdateDownloader', perform: true)
      expect(TariffSynchronizer::TaricUpdateDownloader).to receive(:new)
        .with(example_date)
        .and_return(downlader)
      described_class.download(example_date)
    end
  end

  describe '#import!' do
    let(:taric_update) { create :taric_update }

    before do
      # stub the file_path method to return a valid path of a real file.
      allow(taric_update).to receive(:file_path).and_return('spec/fixtures/taric_samples/insert_record.xml')
    end

    it 'calls the TaricImporter import method' do
      taric_importer = instance_double('TaricImporter')
      expect(TaricImporter).to receive(:new).with(taric_update).and_return(taric_importer)
      expect(taric_importer).to receive(:import)
      taric_update.import!
    end

    it 'marks the Taric update as applied' do
      allow_any_instance_of(TaricImporter).to receive(:import)
      taric_update.import!
      expect(taric_update.reload).to be_applied
    end

    it 'logs an info event' do
      tariff_synchronizer_logger_listener
      allow_any_instance_of(TaricImporter).to receive(:import)
      taric_update.import!
      expect(@logger.logged(:info).size).to eq 1
      expect(@logger.logged(:info).last).to match(/Applied TARIC update/)
    end
  end

  describe '.correct_filename_sequence?' do
    subject(:taric_update) { described_class }

    before do
      create(:taric_update, :applied, example_date: applied_date, sequence_number: applied_sequence_number)
      create(:taric_update, :pending, example_date: pending_date, sequence_number: pending_sequence_number)
    end

    let(:applied_date) { Date.parse('2021-12-01') }
    let(:applied_sequence_number) { '002' }

    context 'when the pending year is the same and the pending sequence is the next valid sequence' do
      let(:pending_date) {  Date.parse('2021-12-02') } # Same year
      let(:pending_sequence_number) { '003' } # Correct sequence

      it { is_expected.to be_correct_filename_sequence }
    end

    context 'when the pending year is the same and the pending sequence is NOT the next valid sequence' do
      let(:pending_date) { Date.parse('2021-12-02') } # Same year
      let(:pending_sequence_number) { '004' } # Incorrect sequence

      it { is_expected.not_to be_correct_filename_sequence }
    end

    context 'when the pending year is the following year and the pending sequence is 001' do
      let(:pending_date) { Date.parse('2022-12-02') } # Following year
      let(:pending_sequence_number) { '001' } # Correct sequence

      it { is_expected.to be_correct_filename_sequence }
    end

    context 'when the pending year is the following year and the pending sequence is NOT the next valid sequence' do
      let(:pending_date) { Date.parse('2022-12-02') } # Following year
      let(:pending_sequence_number) { '002' }           # Incorrect sequence

      it { is_expected.not_to be_correct_filename_sequence }
    end
  end

  describe '#filename_sequence' do
    subject(:taric_update) { create(:taric_update, filename: filename) }

    let(:filename) { '2021-12-30_TGB21257.xml' }

    it 'returns the year and sequence number' do
      expect(taric_update.filename_sequence.named_captures).to eq('year' => '21', 'sequence' => '257')
    end
  end
end
