RSpec.describe Notifications::EnqueueService do
  describe '#call' do
    it 'succeeds without retrying when the block does not raise' do
      enqueued = []

      result = described_class.new(%w[a b], pipeline: 'test_pipeline') { |item| enqueued << item }.call

      expect(enqueued).to eq(%w[a b])
      expect(result.failed_items).to eq([])
      expect(result.attempts).to eq(1)
    end

    it 'retries a failing item, fires enqueue_retrying, then succeeds on a later attempt' do
      allow(Notifications::Instrumentation).to receive(:enqueue_retrying)
      attempts_seen = Hash.new(0)

      result = described_class.new(%w[a], pipeline: 'test_pipeline', retry_delay: 0) { |item|
        attempts_seen[item] += 1
        raise 'boom' if attempts_seen[item] == 1
      }.call

      expect(result.failed_items).to eq([])
      expect(Notifications::Instrumentation).to have_received(:enqueue_retrying).with(
        pipeline: 'test_pipeline', item: 'a', attempt: 1, error_class: 'RuntimeError', error_message: 'boom',
      )
    end

    it 'fires enqueue_failed, alerts Slack, and returns the still-failing items after max_attempts' do
      allow(Notifications::Instrumentation).to receive(:enqueue_failed)
      allow(SlackNotifierService).to receive(:call)

      result = described_class.new(%w[a], pipeline: 'test_pipeline', max_attempts: 2, retry_delay: 0) { |_item| raise 'boom' }.call

      expect(result.failed_items).to eq(%w[a])
      expect(result.attempts).to eq(2)
      expect(Notifications::Instrumentation).to have_received(:enqueue_failed).with(pipeline: 'test_pipeline', items: %w[a], attempts: 2)
      expect(SlackNotifierService).to have_received(:call).with('test_pipeline: failed to enqueue notification for a after 2 attempts — check logs')
    end

    it 'does not sleep after the final attempt' do
      instance = described_class.new(%w[a], pipeline: 'test_pipeline', max_attempts: 2, retry_delay: 0) { |_item| raise 'boom' }
      allow(instance).to receive(:sleep)

      instance.call

      expect(instance).to have_received(:sleep).once
    end

    it 'does not re-invoke a successful item\'s block while another item is still retrying' do
      allow(Notifications::Instrumentation).to receive(:enqueue_retrying)
      succeeded_calls = 0
      failed_attempts = Hash.new(0)

      result = described_class.new(%w[good bad], pipeline: 'test_pipeline', max_attempts: 3, retry_delay: 0) { |item|
        if item == 'good'
          succeeded_calls += 1
        else
          failed_attempts[item] += 1
          raise 'boom'
        end
      }.call

      expect(succeeded_calls).to eq(1)
      expect(failed_attempts['bad']).to eq(3)
      expect(result.failed_items).to eq(%w[bad])
      expect(result.attempts).to eq(3)
    end

    it 'rescues a Slack failure and logs it instead of raising' do
      allow(SlackNotifierService).to receive(:call).and_raise('slack down')
      allow(Rails.logger).to receive(:error)

      expect {
        described_class.new(%w[a], pipeline: 'test_pipeline', max_attempts: 1, retry_delay: 0) { |_item| raise 'boom' }.call
      }.not_to raise_error

      expect(Rails.logger).to have_received(:error).with(a_string_including('test_pipeline_notification_slack_failed'))
    end
  end
end
