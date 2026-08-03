RSpec.describe TariffSynchronizer::Import::Error do
  before do
    allow(Rails.logger).to receive(:error)
  end

  describe '#initialize' do
    it 'requires a message and a source' do
      expect { described_class.new }.to raise_error(ArgumentError)
    end

    it 'defaults original to nil and context to an empty hash' do
      error = described_class.new(message: 'boom', source: :taric)

      expect(error.original).to be_nil
      expect(error.context).to eq({})
    end

    it 'exposes message, source, original and context', :aggregate_failures do
      original = StandardError.new('root cause')

      error = described_class.new(
        message: 'boom',
        source: :cds,
        original:,
        context: { key: 'AdditionalCode' },
      )

      expect(error.message).to eq('boom')
      expect(error.source).to eq(:cds)
      expect(error.original).to eq(original)
      expect(error.context).to eq(key: 'AdditionalCode')
    end
  end

  describe 'logging on construction' do
    it 'logs itself exactly once' do
      described_class.new(message: 'boom', source: :taric)

      expect(Rails.logger).to have_received(:error).once
    end

    it 'capitalizes the source and includes the message when there is no original' do
      described_class.new(message: 'boom', source: :taric)

      expect(Rails.logger).to have_received(:error).with(include('Taric import failed: boom'))
    end

    it "logs the original exception's message instead of its own when an original is present" do
      original = begin
        raise 'root cause'
      rescue StandardError => e
        e
      end

      described_class.new(message: 'wrapper message', source: :cds, original:)

      expect(Rails.logger).to have_received(:error).with(include('Cds import failed: root cause'))
    end

    it 'includes each context entry on its own line', :aggregate_failures do
      transaction = { 'id' => 1 }
      described_class.new(
        message: 'boom',
        source: :taric,
        context: { transaction:, key: 'Foo' },
      )

      expect(Rails.logger).to have_received(:error).with(include("Transaction: #{transaction}"))
      expect(Rails.logger).to have_received(:error).with(include('Key: Foo'))
    end

    it "includes the original exception's backtrace when available" do
      original = begin
        raise 'root cause'
      rescue StandardError => e
        e
      end

      described_class.new(message: 'wrapper', source: :taric, original:)

      expect(Rails.logger).to have_received(:error).with(include('Backtrace:'))
    end

    it 'omits the backtrace section when neither the wrapper nor an original exception has one' do
      described_class.new(message: 'boom', source: :taric)

      expect(Rails.logger).to have_received(:error).with(satisfy { |message| !message.include?('Backtrace:') })
    end
  end
end
