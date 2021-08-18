require 'tariff_synchronizer/taric_sequence_checker'
require 'tariff_synchronizer/tariff_updates_requester'
require 'tariff_synchronizer/file_service'
require 'tariff_synchronizer/response'

describe TariffSynchronizer::TaricSequenceChecker do
  subject { described_class.new(with_email) }

  let(:response) { TariffSynchronizer::Response.new(200, "abc\ndef.xml") }
  let(:with_email) { false }
  let(:mail) { double }

  before do
    allow_any_instance_of(described_class).to receive(:interval).and_return(Date.new(2020, 0o1, 0o1)..Date.new(2020, 0o1, 0o1))
    allow(TariffSynchronizer::TariffUpdatesRequester).to receive(:perform).and_return(response)
    allow(TariffSynchronizer::Mailer).to receive(:failed_taric_sequence).and_return(mail)
    allow(mail).to receive(:deliver_now)
  end

  describe '#perform' do
    it 'increases retry limit' do
      expect(TariffSynchronizer).to receive(:retry_count=).with(5000)
      expect(TariffSynchronizer).to receive(:exception_retry_count=).with(2500)
      subject.send(:increase_retry_limit)
    end

    it 'sets back retry limit' do
      expect(TariffSynchronizer).to receive(:retry_count=).with(1)
      expect(TariffSynchronizer).to receive(:exception_retry_count=).with(1)
      subject.send(:restore_retry_limit)
    end

    context 'when there are NO missing files' do
      before do
        allow(TariffSynchronizer::FileService).to receive(:file_exists?).and_return(true)
      end

      it 'returns empty array' do
        expect(subject.perform).to eq([])
      end
    end

    context 'when there are missing files' do
      before do
        allow(TariffSynchronizer::FileService).to receive(:file_exists?).and_return(false)
      end

      it 'returns array with only xml files' do
        expect(subject.perform).to eq(['2020-01-01_def.xml'])
      end
    end

    context 'with email' do
      let(:with_email) { true }

      it 'calls Mailer failed_taric_sequence' do
        expect(TariffSynchronizer::Mailer).to receive(:failed_taric_sequence).with(['2020-01-01_def.xml'])
        subject.perform
      end
    end
  end
end
