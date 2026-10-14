require 'rails_helper'

RSpec.describe Evaluation::RunLabelGenerator do
  subject(:result) { described_class.call(run, overrides, ai_client:) }

  let(:ai_client) { instance_double(OpenaiClient) }
  let(:run) { create(:evaluation_run) }
  let(:overrides) { {} }

  context 'when there are no overrides at all' do
    before { allow(ai_client).to receive(:call) }

    it 'stores "default settings" without calling the AI client' do
      expect(result).to eq('default settings')

      expect(ai_client).not_to have_received(:call)
      expect(run.reload.label).to eq('default settings')
    end
  end

  context 'when there are overrides' do
    let(:overrides) { { 'retrieval_method' => 'vector' } }

    before { allow(ai_client).to receive(:call).and_return({ 'label' => 'vector based retrieval' }) }

    it 'returns the generated label and persists it on the run' do
      expect(result).to eq('vector based retrieval')
      expect(run.reload.label).to eq('vector based retrieval')
    end

    it 'calls the AI client once with the overridden settings in the prompt' do
      result

      expect(ai_client).to have_received(:call).once.with(
        array_including(
          hash_including(role: 'system', content: a_string_including('EXACTLY THREE')),
          hash_including(role: 'user', content: a_string_including('retrieval_method: vector')),
        ),
        model: 'gpt-5-mini-2025-08-07',
        event_kind: 'evaluation_run_label_generation',
        timeout: 60,
      )
    end
  end

  context 'with more than one overridden key' do
    let(:overrides) { { 'candidate_limit' => 80, 'max_rounds' => 2 } }

    before { allow(ai_client).to receive(:call).and_return({ 'label' => 'wide candidate pool' }) }

    it 'includes every overridden key in the prompt, exactly as given -- it never merges or re-derives anything itself' do
      result

      expect(ai_client).to have_received(:call) do |messages, **|
        user_message = messages.last[:content]
        expect(user_message).to include('candidate_limit: 80')
        expect(user_message).to include('max_rounds: 2')
      end
    end
  end

  context 'when the model returns an acceptable label on the first attempt' do
    let(:overrides) { { 'retrieval_method' => 'hybrid' } }

    before { allow(ai_client).to receive(:call).and_return({ 'label' => 'hybrid search strategy' }) }

    it 'does not retry' do
      result

      expect(ai_client).to have_received(:call).once
    end
  end

  context 'when the first attempt fails validation and the second succeeds' do
    let(:overrides) { { 'retrieval_method' => 'vector' } }

    before do
      allow(ai_client).to receive(:call).and_return(
        { 'label' => 'two words' },
        { 'label' => 'vector based retrieval' },
      )
    end

    it 'retries and returns the label from the successful attempt' do
      expect(result).to eq('vector based retrieval')
      expect(ai_client).to have_received(:call).twice
    end
  end

  context 'when every attempt fails validation' do
    let(:overrides) { { 'retrieval_method' => 'vector' } }

    before { allow(ai_client).to receive(:call).and_return({ 'label' => 'two words' }) }

    it 'returns nil after 3 attempts and leaves the run unlabelled' do
      expect(result).to be_nil
      expect(ai_client).to have_received(:call).exactly(3).times
      expect(run.reload.label).to be_nil
    end
  end

  context 'when the AI client raises a retryable error on every attempt' do
    let(:overrides) { { 'retrieval_method' => 'vector' } }

    before do
      allow(ai_client).to receive(:call).and_raise(OpenaiClient::ApiError.new(status: 500, body: 'nope'))
      allow(Rails.logger).to receive(:warn)
    end

    it 'returns nil without raising, and logs a warning including the HTTP status' do
      expect(result).to be_nil
      expect(Rails.logger).to have_received(:warn).with(/Run label generation failed for run #{run.id}/).exactly(3).times
      expect(Rails.logger).to have_received(:warn).with(/status=500/).exactly(3).times
    end
  end

  context 'when the AI client exceeds its per-attempt deadline on every attempt' do
    let(:overrides) { { 'retrieval_method' => 'vector' } }

    before do
      allow(ai_client).to receive(:call).and_raise(
        OpenaiClient::DeadlineExceeded.new(timeout_seconds: 60, elapsed_seconds: 60.4),
      )
      allow(Rails.logger).to receive(:warn)
    end

    it 'returns nil without raising, and logs the elapsed time' do
      expect(result).to be_nil
      expect(ai_client).to have_received(:call).exactly(3).times
      expect(Rails.logger).to have_received(:warn).with(/elapsed=60\.4s/).exactly(3).times
    end
  end

  describe 'the acceptability filter' do
    let(:overrides) { { 'retrieval_method' => 'vector' } }

    # A plain method, not a `let`, to keep this describe block's memoized-helper count under
    # RuboCop's RSpec/MultipleMemoizedHelpers limit (it counts inherited `let`s too).
    def stub_label(label)
      allow(ai_client).to receive(:call).and_return({ 'label' => label })
    end

    it 'rejects a label with only two words' do
      stub_label('vector retrieval')
      expect(result).to be_nil
    end

    it 'rejects a label with four words' do
      stub_label('uses vector based retrieval')
      expect(result).to be_nil
    end

    it 'rejects a label containing a banned meta word' do
      stub_label('custom default configuration')
      expect(result).to be_nil
    end

    it 'rejects a label containing a number' do
      stub_label('top 5 retrieval')
      expect(result).to be_nil
    end

    it 'rejects a label containing punctuation' do
      stub_label('vector-based, retrieval')
      expect(result).to be_nil
    end
  end

  context 'when the label value is not a String' do
    let(:overrides) { { 'retrieval_method' => 'vector' } }

    before { allow(ai_client).to receive(:call).and_return({ 'label' => %w[vector based retrieval] }) }

    it 'rejects the whole attempt instead of coercing it into a fake-looking label' do
      expect(result).to be_nil
    end
  end
end
