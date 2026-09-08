require 'rails_helper'

RSpec.describe RetrySupport::WithRetry do
  subject(:host) { host_class.new }

  let(:retryable_error) { Faraday::TimeoutError.new('timeout') }
  let(:delay_calculator) { ->(attempt, _error) { attempt * 2 } }

  let(:host_class) do
    Class.new do
      include RetrySupport::WithRetry
    end
  end

  before { allow(Kernel).to receive(:sleep) }

  it 'returns when the first attempt succeeds' do
    attempts = 0

    result = host.with_retry(
      max_attempts: 3,
      retryable_errors: [Faraday::TimeoutError],
      delay_calculator:,
    ) do
      attempts += 1
      'ok'
    end

    expect(result).to eq('ok')
    expect(attempts).to eq(1)
    expect(Kernel).not_to have_received(:sleep)
  end

  it 'retries retryable errors until success' do
    attempts = 0

    result = host.with_retry(
      max_attempts: 3,
      retryable_errors: [Faraday::TimeoutError],
      delay_calculator:,
    ) do
      attempts += 1
      raise retryable_error if attempts < 3

      'ok'
    end

    expect(result).to eq('ok')
    expect(attempts).to eq(3)
    expect(Kernel).to have_received(:sleep).with(2).once
    expect(Kernel).to have_received(:sleep).with(4).once
  end

  it 'raises after exhausting attempts' do
    attempts = 0

    expect {
      host.with_retry(
        max_attempts: 3,
        retryable_errors: [Faraday::TimeoutError],
        delay_calculator:,
      ) do
        attempts += 1
        raise retryable_error
      end
    }.to raise_error(Faraday::TimeoutError)

    expect(attempts).to eq(3)
    expect(Kernel).to have_received(:sleep).with(2).once
    expect(Kernel).to have_received(:sleep).with(4).once
  end

  it 'does not retry non-retryable errors' do
    attempts = 0

    expect {
      host.with_retry(
        max_attempts: 3,
        retryable_errors: [Faraday::TimeoutError],
        delay_calculator:,
      ) do
        attempts += 1
        raise ArgumentError, 'invalid'
      end
    }.to raise_error(ArgumentError, 'invalid')

    expect(attempts).to eq(1)
    expect(Kernel).not_to have_received(:sleep)
  end

  it 'invokes lifecycle hooks with retry metadata' do
    retries = []
    exhausted = nil

    expect {
      host.with_retry(
        max_attempts: 2,
        retryable_errors: [Faraday::TimeoutError],
        delay_calculator:,
        on_retry: ->(**payload) { retries << payload },
        on_exhausted: ->(**payload) { exhausted = payload },
      ) do
        raise retryable_error
      end
    }.to raise_error(Faraday::TimeoutError)

    expect(retries).to eq([{ attempt: 1, max_attempts: 2, delay: 2, error: retryable_error }])
    expect(exhausted).to eq({ attempt: 2, max_attempts: 2, error: retryable_error })
  end

  it 'invokes on_success with attempt metadata' do
    success_payload = nil

    result = host.with_retry(
      max_attempts: 2,
      retryable_errors: [Faraday::TimeoutError],
      delay_calculator:,
      on_success: ->(**payload) { success_payload = payload },
    ) { 'ok' }

    expect(result).to eq('ok')
    expect(success_payload).to include(attempt: 1, max_attempts: 2, result: 'ok')
  end

  context 'when options are omitted' do
    it 'does not rescue errors without retryable_errors' do
      attempts = 0

      expect {
        host.with_retry do
          attempts += 1
          raise Faraday::TimeoutError, 'timeout'
        end
      }.to raise_error(Faraday::TimeoutError)

      expect(attempts).to eq(1)
      expect(Kernel).not_to have_received(:sleep)
    end
  end
end
