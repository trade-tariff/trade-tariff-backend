RSpec.describe TariffSynchronizer::TaricSequenceChecker do
  subject(:checker) { described_class.new }

  describe '#perform' do
    before do
      allow(TariffSynchronizer).to receive(:exception_retry_count=).and_call_original
      allow(TariffSynchronizer).to receive(:retry_count=).and_call_original
      allow(TariffSynchronizer::FileService).to receive(:file_exists?).and_return(files_exist)
      allow(TariffSynchronizer::Mailer).to receive(:failed_taric_sequence).and_call_original
      allow(TariffSynchronizer::TariffUpdatesRequester).to receive(:perform).and_return(response)
    end

    let(:files_exist) { false }
    let(:response) { TariffSynchronizer::Response.new(200, "abc\ndef.xml") }

    # rubocop:disable RSpec/MultipleExpectations
    it 'sets TariffSynchronizer.retry_count correctly' do
      checker.perform
      expect(TariffSynchronizer).to have_received(:retry_count=).ordered.with(5000)
      expect(TariffSynchronizer).to have_received(:retry_count=).ordered.with(1)
    end

    it 'sets TariffSynchronizer.exception_retry_count correctly' do
      checker.perform
      expect(TariffSynchronizer).to have_received(:exception_retry_count=).ordered.with(2500)
      expect(TariffSynchronizer).to have_received(:exception_retry_count=).ordered.with(1)
    end
    # rubocop:enable RSpec/MultipleExpectations

    context 'when no updates are missing' do
      let(:files_exist) { true }

      it { expect(checker.perform).to eq([]) }

      it 'does not call Mailer failed_taric_sequence' do
        checker.perform
        expect(TariffSynchronizer::Mailer).not_to have_received(:failed_taric_sequence)
      end
    end

    context 'when updates are missing' do
      let(:files_exist) { false }
      let(:today) { Time.zone.today }

      let(:expected_files) do
        end_date = Time.zone.today
        start_date = end_date - 2.years
        range = start_date..end_date
        range.map do |day|
          "#{day.iso8601}_def.xml"
        end
      end

      it { expect(checker.perform).to eq(expected_files) }

      it 'calls Mailer failed_taric_sequence' do
        checker.perform
        expect(TariffSynchronizer::Mailer).to have_received(:failed_taric_sequence).with(expected_files)
      end
    end
  end
end
