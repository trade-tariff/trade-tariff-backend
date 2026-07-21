# frozen_string_literal: true

require 'stringio'

RSpec.describe AiUsage::Logger do
  let(:log_output) { StringIO.new }
  let(:test_logger) { ActiveSupport::Logger.new(log_output) }
  let(:log_subscriber) do
    logger = test_logger
    described_class.new.tap do |subscriber|
      subscriber.define_singleton_method(:logger) { logger }
    end
  end

  def build_event
    ActiveSupport::Notifications::Event.new(
      'embedding_api_call_completed.ai_usage',
      Time.current,
      Time.current,
      SecureRandom.hex(5),
      {
        event_kind: 'vector_search_query_embedding',
        model: 'text-embedding-3-small',
        request_id: 'req-1',
        total_tokens: 42,
      },
    )
  end

  it 'includes the current experiment on embedding usage logs' do
    TradeTariffRequest.experiment = 'trstd-trdr'

    log_subscriber.embedding_api_call_completed(build_event)

    log_output.rewind
    expect(JSON.parse(log_output.read.lines.last)).to include(
      'service' => 'ai_usage',
      'event' => 'embedding_api_call_completed',
      'experiment' => 'trstd-trdr',
    )
  ensure
    TradeTariffRequest.experiment = nil
  end

  it 'omits the experiment field outside a labelled request' do
    TradeTariffRequest.experiment = nil

    log_subscriber.embedding_api_call_completed(build_event)

    log_output.rewind
    expect(JSON.parse(log_output.read.lines.last)).not_to have_key('experiment')
  end
end
