RSpec.describe CustomJobLogger do
  let(:logger) { described_class.new(Sidekiq::Config.new) }
  let(:item) do
    {
      'retry' => false,
      'queue' => 'default',
      'args' => ['search', 'CommodityIndex', 10],
      'class' => 'BuildIndexPageWorker',
      'jid' => '11a54a43f3130a57c845350f',
      'created_at' => 1_765_210_947_384,
      'enqueued_at' => 1_765_210_947_384,
      'status' => 'done',
    }
  end

  let(:queue) { 'default' }

  describe '#call' do
    before do
      allow(Sidekiq).to receive(:logger).and_return(Logger.new('/dev/null'))
      allow(Sidekiq.logger).to receive(:info)
      allow(Sidekiq.logger).to receive(:warn)
    end

    context 'when the job succeeds' do
      it 'logs the job completion' do
        logger.call(item, queue) { true }

        expect(Sidekiq.logger).to have_received(:info).with(
          hash_including(
            'args' => ['search', 'CommodityIndex', 10],
            'class' => 'BuildIndexPageWorker',
            'duration' => be_a(Float),
            'jid' => '11a54a43f3130a57c845350f',
            'queries' => 0,
            'queue' => 'default',
            'status' => 'done',
          ),
        )
      end
    end

    context 'when the job fails' do
      let(:error) do
        StandardError.new('Something went wrong').tap do |e|
          e.set_backtrace(['line 1', 'line 2'])
        end
      end

      it 'logs the job failure' do
        expect {
          logger.call(item, queue) { raise error }
        }.to raise_error(StandardError, 'Something went wrong')

        expect(Sidekiq.logger).to have_received(:warn)
        .with(
          hash_including(
            'args' => ['search', 'CommodityIndex', 10],
            'class' => 'BuildIndexPageWorker',
            'duration' => be_a(Float),
            'error_class' => 'StandardError',
            'error_message' => 'Something went wrong',
            'jid' => '11a54a43f3130a57c845350f',
            'queries' => 0,
            'queue' => 'default',
            'status' => 'fail',
          ),
        )
      end
    end
  end
end
