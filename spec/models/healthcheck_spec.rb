RSpec.describe Healthcheck do
  subject(:instance) { described_class.instance }

  before do
    search_result = Beta::Search::SearchQueryParserResult.new
    service_double = instance_double('Api::Beta::SearchQueryParserService', call: search_result)

    allow(Api::Beta::SearchQueryParserService).to receive(:new).and_return(service_double)
  end

  describe '#current_revision' do
    subject { instance.current_revision }

    before do
      instance.instance_variable_set(:@current_revision, nil)
      allow(File).to receive(:read).and_call_original
      allow(File).to receive(:file?).and_call_original
    end

    after { instance.instance_variable_set(:@current_revision, nil) }

    context 'with revision file' do
      before do
        allow(File).to receive(:file?).with(described_class::REVISION_FILE)
                                      .and_return true

        allow(File).to receive(:read).with(described_class::REVISION_FILE)
                                     .and_return "ABCDEF01\n"
      end

      it { is_expected.to eql 'ABCDEF01' }
    end

    context 'with unreadable revision file' do
      before do
        allow(File).to receive(:file?).with(described_class::REVISION_FILE)
                                      .and_return true

        allow(File).to receive(:read).with(described_class::REVISION_FILE)
                                     .and_raise Errno::EACCES
      end

      it { is_expected.to eql 'test' }
    end

    context 'without revision file' do
      it { is_expected.to eql 'test' }
    end
  end

  describe '#check' do
    subject(:check) { instance.check }

    context 'with broken db connection' do
      before do
        allow(Sequel::Model.db).to receive(:test_connection).and_return(false)
      end

      it { expect(check).to include postgres: false }
    end

    describe 'sidekiq health' do
      context 'with no cache key' do
        before { TradeTariffBackend.redis.del described_class::SIDEKIQ_KEY }

        it { is_expected.to include sidekiq: false }
      end

      context 'with recent cache key' do
        before do
          TradeTariffBackend.redis.set \
            described_class::SIDEKIQ_KEY,
            (described_class::SIDEKIQ_THRESHOLD - 1.minute).ago.utc.iso8601
        end

        it { is_expected.to include sidekiq: true }
      end

      context 'with outdated cache key' do
        before do
          TradeTariffBackend.redis.set \
            described_class::SIDEKIQ_KEY,
            (described_class::SIDEKIQ_THRESHOLD + 1.minute).ago.utc.iso8601
        end

        it { is_expected.to include sidekiq: false }
      end
    end
  end

  describe '.check' do
    subject { described_class.check }

    before do
      TradeTariffBackend.redis.set \
        described_class::SIDEKIQ_KEY,
        (described_class::SIDEKIQ_THRESHOLD - 1.minute).ago.utc.iso8601
    end

    let(:expected) do
      {
        git_sha1: 'test',
        opensearch: true,
        postgres: true,
        redis: true,
        search_query_parser: true,
        sidekiq: true,
      }
    end

    it { is_expected.to eql expected }
  end
end
