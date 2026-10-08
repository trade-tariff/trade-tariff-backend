RSpec.describe SidekiqDeathHandler do
  let(:job) do
    {
      'class' => 'EnquiryForm::SendSubmissionEmailWorker',
      'jid' => '93ce163da1a9f7052e55d7c6',
      'queue' => 'default',
      'args' => %w[TVUZGFEA],
      'error_class' => 'Redis::CannotConnectError',
      'error_message' => 'user specified timeout for redis-production:6379',
      'retry_count' => 25,
    }
  end

  let(:exception) do
    StandardError.new('user specified timeout').tap do |e|
      e.set_backtrace((1..12).map { |number| "app/workers/example_worker.rb:#{number}" })
    end
  end

  let(:sent_arguments) { {} }

  before do
    allow(TradeTariffBackend).to receive(:slack_failures_enabled?).and_return(true)
    allow(SlackNotifierService).to receive(:call) { |**arguments| sent_arguments.merge!(arguments) }
    allow(CloudwatchLogsInsightsLink).to receive(:for_job).and_return('https://logs.example/insights')
    travel_to Time.utc(2026, 9, 21, 12, 0, 0)
  end

  def sent_field(title)
    sent_arguments[:attachments].first[:fields].find { |field| field[:title] == title }
  end

  it 'includes the first 10 backtrace lines in a code block' do
    described_class.call(job, exception)

    expected_lines = (1..10).map { |number| "app/workers/example_worker.rb:#{number}" }
    expect(sent_field('Backtrace')).to eq(
      title: 'Backtrace',
      value: "```#{expected_lines.join("\n")}```",
      short: false,
    )
  end

  context 'when the exception has no backtrace' do
    let(:exception) { StandardError.new('user specified timeout') }

    it 'says that there is no backtrace' do
      described_class.call(job, exception)

      expect(sent_field('Backtrace')[:value]).to eq('No backtrace')
    end
  end

  it 'links to the CloudWatch logs for the job' do
    described_class.call(job, exception)

    expect(sent_field('Logs')).to eq(
      title: 'Logs',
      value: '<https://logs.example/insights|View logs in CloudWatch>',
      short: false,
    )
  end

  context 'when the job has a failed_at time' do
    let(:job) { super().merge('failed_at' => Time.utc(2026, 9, 20, 9, 0, 0).to_i * 1000) }

    it 'scopes the logs from 5 minutes before the first failure to 5 minutes after now' do
      described_class.call(job, exception)

      expect(CloudwatchLogsInsightsLink).to have_received(:for_job).with(
        jid: '93ce163da1a9f7052e55d7c6',
        from: Time.utc(2026, 9, 20, 8, 55, 0),
        to: Time.utc(2026, 9, 21, 12, 5, 0),
      )
    end
  end

  context 'when the job has no failed_at time' do
    it 'scopes the logs from 15 minutes before now to 5 minutes after now' do
      described_class.call(job, exception)

      expect(CloudwatchLogsInsightsLink).to have_received(:for_job).with(
        jid: '93ce163da1a9f7052e55d7c6',
        from: Time.utc(2026, 9, 21, 11, 45, 0),
        to: Time.utc(2026, 9, 21, 12, 5, 0),
      )
    end
  end

  it 'sends a Slack alert with structured error details' do
    described_class.call(job, exception)

    expect(SlackNotifierService).to have_received(:call).with(
      channel: TradeTariffBackend.slack_failures_channel,
      attachments: [
        hash_including(
          color: 'danger',
          title: ':fire: Job dead: EnquiryForm::SendSubmissionEmailWorker',
          fields: include(
            hash_including(title: 'Error', value: include('Redis::CannotConnectError')),
            hash_including(title: 'JID', value: '93ce163da1a9f7052e55d7c6'),
            hash_including(title: 'Queue', value: 'default'),
            hash_including(title: 'Args', value: include('TVUZGFEA')),
            hash_including(title: 'Retries exhausted', value: '25'),
          ),
        ),
      ],
    )
  end

  context 'when slack failures are disabled' do
    before do
      allow(TradeTariffBackend).to receive(:slack_failures_enabled?).and_return(false)
    end

    it 'does not send a Slack alert' do
      described_class.call(job, exception)

      expect(SlackNotifierService).not_to have_received(:call)
    end
  end

  context 'when the job has no error fields (retry: false)' do
    let(:job) do
      {
        'class' => 'RefreshAppendix5aGuidanceWorker',
        'jid' => 'abc123',
        'queue' => 'default',
        'args' => [],
      }
    end

    let(:exception) { RuntimeError.new('SMTP connection timed out') }

    it 'falls back to the exception object for error details' do
      described_class.call(job, exception)

      expect(SlackNotifierService).to have_received(:call).with(
        channel: TradeTariffBackend.slack_failures_channel,
        attachments: [
          hash_including(
            fields: include(
              hash_including(title: 'Error', value: include('RuntimeError', 'SMTP connection timed out')),
            ),
          ),
        ],
      )
    end
  end

  context 'when the job has slack_alerts: false' do
    let(:job) { super().merge('slack_alerts' => false) }

    it 'does not send a Slack alert' do
      described_class.call(job, exception)

      expect(SlackNotifierService).not_to have_received(:call)
    end
  end

  context 'when the job sets slack_channel' do
    let(:job) { super().merge('slack_channel' => '#tariffs-etl') }

    it 'routes the alert through the notifier' do
      notifier = Slack::Notifier.new('https://hooks.slack.example/test')
      allow(notifier).to receive(:post)
      allow(Rails.application.config).to receive(:slack_notifier).and_return(notifier)
      allow(SlackNotifierService).to receive(:call).and_call_original

      described_class.call(job, exception)

      expect(notifier).to have_received(:post).with(
        hash_including(channel: '#tariffs-etl', attachments: be_present),
      )
    end

    context 'when alerts are opted out' do
      let(:job) { super().merge('slack_alerts' => false) }

      it 'does not send a Slack alert' do
        described_class.call(job, exception)

        expect(SlackNotifierService).not_to have_received(:call)
      end
    end
  end

  [nil, '', ' '].each do |channel|
    context "when slack_channel is #{channel.inspect}" do
      let(:job) { super().merge('slack_channel' => channel) }

      it 'uses the configured failure channel' do
        allow(TradeTariffBackend).to receive(:slack_failures_channel).and_return('#default-failures')

        described_class.call(job, exception)

        expect(SlackNotifierService).to have_received(:call).with(
          hash_including(channel: '#default-failures'),
        )
      end
    end
  end
end
