require 'stringio'

RSpec.describe Search::Metrics do
  subject(:record) { described_class.record(event, output:, environment: 'production', service: 'uk', now:) }

  let(:output) { StringIO.new }
  let(:now) { Time.utc(2026, 9, 22, 12) }
  let(:event) { ActiveSupport::Notifications::Event.new('search_completed.search', now, now, 'id', payload) }
  let(:payload) do
    {
      request_source: 'frontend',
      search_type: 'classic',
      total_duration_ms: 1500,
      result_count: 4,
      commodity_result_count: 2,
      results_type: 'fuzzy_search',
    }
  end
  let(:emitted) { JSON.parse(output.string) }

  def dimension_sets(metric_name)
    emitted.dig('_aws', 'CloudWatchMetrics')
      .find { |definition| definition.dig('Metrics', 0, 'Name') == metric_name }
      .fetch('Dimensions')
  end

  it 'emits a completed search without request identifiers as dimensions' do
    expect(record).to be(true)
    expect(emitted).to include(
      'Environment' => 'production',
      'Service' => 'uk',
      'RequestSource' => 'frontend',
      'SearchType' => 'classic',
      'Outcome' => 'completed',
      'SearchEvents' => 1,
      'SearchDuration' => 1.5,
      'ResultCount' => 4,
      'CommodityResultCount' => 2,
    )
    expect(emitted).not_to have_key('EmptyResults')
    expect(emitted.dig('_aws', 'Timestamp')).to eq((now.to_f * 1000).to_i)
    expect(emitted.dig('_aws', 'CloudWatchMetrics').map { |definition| definition['Namespace'] }.uniq).to eq(['TradeTariff/Search'])
    expect(emitted.dig('_aws', 'CloudWatchMetrics').flat_map { |definition| definition['Dimensions'].flatten }).not_to include('request_id')
    expect(dimension_sets('SearchEvents')).to eq([
      %w[Environment Service RequestSource Outcome],
      %w[Environment Service SearchType Outcome],
      %w[Environment Service Outcome],
    ])
    expect(dimension_sets('SearchDuration')).to eq([%w[Environment Service]])
  end

  it 'counts a classic fuzzy search with zero commodity hits as empty' do
    payload[:commodity_result_count] = 0

    record

    expect(emitted['EmptyResults']).to eq(1)
    expect(emitted['CommodityResultCount']).to eq(0)
  end

  it 'does not count an exact classic match with zero commodity hits as empty' do
    payload[:commodity_result_count] = 0
    payload[:results_type] = 'exact_search'

    record

    expect(emitted).not_to have_key('EmptyResults')
  end

  it 'does not count an exact classic match when the result type is a symbol' do
    payload[:commodity_result_count] = 0
    payload[:results_type] = :exact_search

    record

    expect(emitted).not_to have_key('EmptyResults')
  end

  it 'counts a classic zero commodity result when the result type is omitted' do
    payload.delete(:results_type)
    payload[:commodity_result_count] = 0

    record

    expect(emitted['EmptyResults']).to eq(1)
  end

  it 'does not treat missing counts as empty' do
    payload.delete(:commodity_result_count)
    payload.delete(:result_count)

    record

    expect(emitted).not_to have_key('EmptyResults')

    output.truncate(0)
    output.rewind
    described_class.record(
      ActiveSupport::Notifications::Event.new(
        'search_completed.search', now, now, 'id',
        payload.merge(search_type: 'interactive', result_count: nil)
      ),
      output:, environment: 'production', service: 'uk', now:,
    )
    expect(JSON.parse(output.string)).not_to have_key('EmptyResults')
  end

  it 'keeps the search event when a duration or count is not finite' do
    payload[:total_duration_ms] = Float::NAN
    payload[:result_count] = Float::INFINITY

    record

    expect(emitted['SearchEvents']).to eq(1)
    expect(emitted).not_to have_key('SearchDuration')
    expect(emitted).not_to have_key('ResultCount')
  end

  it 'counts a classic search with no commodity count and zero results as empty' do
    payload.delete(:commodity_result_count)
    payload[:result_count] = 0

    record

    expect(emitted['EmptyResults']).to eq(1)
    expect(emitted).not_to have_key('CommodityResultCount')
  end

  it 'keeps the historical exact-labelled fallback when the commodity count is absent' do
    payload.delete(:commodity_result_count)
    payload[:result_count] = 0
    payload[:results_type] = 'exact_search'

    expect(record).to be(true)
    expect(emitted['SearchEvents']).to eq(1)
    expect(emitted['EmptyResults']).to eq(1)
    expect(emitted['ResultCount']).to eq(0)
    expect(emitted).not_to have_key('CommodityResultCount')
  end

  it 'does not treat an invalid supplied count as an observed empty' do
    ['bad', '0', '', ' 0 ', true, false, -1, Float::NAN, Float::INFINITY].each do |invalid|
      output.truncate(0)
      output.rewind
      recorded = described_class.record(
        ActiveSupport::Notifications::Event.new(
          'search_completed.search', now, now, 'id',
          payload.merge(commodity_result_count: invalid, result_count: 0, results_type: 'fuzzy_search')
        ),
        output:, environment: 'production', service: 'uk', now:,
      )

      emitted_line = JSON.parse(output.string)
      expect(recorded).to be(true)
      expect(emitted_line['SearchEvents']).to eq(1)
      expect(emitted_line).not_to have_key('EmptyResults')
      expect(emitted_line).not_to have_key('CommodityResultCount')
      expect(emitted_line['ResultCount']).to eq(0)

      output.truncate(0)
      output.rewind
      recorded = described_class.record(
        ActiveSupport::Notifications::Event.new(
          'search_completed.search', now, now, 'id',
          payload.except(:commodity_result_count).merge(result_count: invalid, results_type: 'exact_search')
        ),
        output:, environment: 'production', service: 'uk', now:,
      )
      emitted_line = JSON.parse(output.string)
      expect(recorded).to be(true)
      expect(emitted_line['SearchEvents']).to eq(1)
      expect(emitted_line).not_to have_key('EmptyResults')
      expect(emitted_line).not_to have_key('ResultCount')
    end
  end

  it 'does not fall back when a supplied commodity count is rejected' do
    payload[:commodity_result_count] = 'bad'
    payload[:result_count] = 0
    payload[:results_type] = 'exact_search'

    expect(record).to be(true)
    expect(emitted['SearchEvents']).to eq(1)
    expect(emitted).not_to have_key('EmptyResults')
  end

  it 'does not count invalid guided result counts as empty' do
    %w[interactive internal].each do |search_type|
      ['bad', '0', true, false, -1, Float::NAN, Float::INFINITY].each do |invalid|
        output.truncate(0)
        output.rewind
        recorded = described_class.record(
          ActiveSupport::Notifications::Event.new(
            'search_completed.search', now, now, 'id',
            payload.merge(search_type:, result_count: invalid, commodity_result_count: nil)
          ),
          output:, environment: 'production', service: 'uk', now:,
        )

        emitted_line = JSON.parse(output.string)
        expect(recorded).to be(true)
        expect(emitted_line['SearchEvents']).to eq(1)
        expect(emitted_line).not_to have_key('EmptyResults')
        expect(emitted_line).not_to have_key('ResultCount')
      end
    end
  end

  it 'counts interactive and internal zero-result searches, but not other types' do
    %w[interactive internal].each do |search_type|
      output.truncate(0)
      output.rewind
      described_class.record(
        ActiveSupport::Notifications::Event.new('search_completed.search', now, now, 'id', payload.merge(search_type:, result_count: 0)),
        output:, environment: 'production', service: 'uk', now:,
      )
      expect(JSON.parse(output.string)['EmptyResults']).to eq(1)
    end

    output.truncate(0)
    output.rewind
    described_class.record(
      ActiveSupport::Notifications::Event.new('search_completed.search', now, now, 'id', payload.merge(search_type: 'classification', result_count: 0)),
      output:, environment: 'production', service: 'uk', now:,
    )
    expect(JSON.parse(output.string)).not_to have_key('EmptyResults')
  end

  it 'records a failed search without duration or result counts' do
    event_name = 'search_failed.search'
    failed = ActiveSupport::Notifications::Event.new(event_name, now, now, 'id', { search_type: 'interactive' })

    described_class.record(failed, output:, environment: 'staging', service: 'xi', now:)

    expect(emitted).to include('Outcome' => 'failed', 'SearchType' => 'interactive', 'RequestSource' => 'unknown', 'SearchEvents' => 1)
    expect(emitted).not_to have_key('SearchDuration')
  end

  it 'collapses unexpected labels and ignores unrelated events' do
    payload[:request_source] = 'browser-extension'
    payload[:search_type] = 'horse'

    record

    expect(emitted).to include('RequestSource' => 'other', 'SearchType' => 'other')

    output.truncate(0)
    output.rewind
    ignored = ActiveSupport::Notifications::Event.new('search_started.search', now, now, 'id', payload)
    expect(described_class.record(ignored, output:, environment: 'production', service: 'uk', now:)).to be(false)
    expect(output.string).to eq('')
  end

  it 'emits selection, expansion, and AI call metrics in seconds' do
    described_class.record(
      ActiveSupport::Notifications::Event.new('result_selected.search', now, now, 'id', {}),
      output:, environment: 'production', service: 'uk', now:,
    )
    described_class.record(
      ActiveSupport::Notifications::Event.new('query_expanded.search', now, now, 'id', {}),
      output:, environment: 'production', service: 'uk', now:,
    )
    described_class.record(
      ActiveSupport::Notifications::Event.new('api_call_completed.search', now, now, 'id', { duration_ms: 250 }),
      output:, environment: 'production', service: 'uk', now:,
    )

    lines = output.string.lines.map { |line| JSON.parse(line) }
    expect(lines.map { |line| line.except('_aws', 'Environment', 'Service') }).to eq([
      { 'ResultSelections' => 1 },
      { 'QueryExpansions' => 1 },
      { 'AiApiDuration' => 0.25, 'Operation' => 'unknown', 'ResponseType' => 'unknown', 'AiApiCalls' => 1 },
    ])
    expect(lines.last.dig('_aws', 'CloudWatchMetrics', 0, 'Metrics', 0)).to include('Name' => 'AiApiDuration', 'Unit' => 'Seconds')
  end

  describe 'operations metrics' do
    def record_operation(name, attributes = {})
      output.truncate(0)
      output.rewind
      notification = ActiveSupport::Notifications::Event.new("#{name}.search", now, now, 'id', attributes)
      described_class.record(notification, output:, environment: 'production', service: 'xi', now:)
      JSON.parse(output.string) unless output.string.empty?
    end

    it 'keeps overall AI latency and adds bounded operation and response dimensions' do
      result = record_operation('api_call_completed', operation: 'search_query_expansion', response_type: 'error', duration_ms: 3780)

      expect(result).to include('Service' => 'xi', 'AiApiCalls' => 1, 'AiApiDuration' => 3.78, 'Operation' => 'search_query_expansion', 'ResponseType' => 'error')
      expect(dimension_sets('AiApiDuration')).to eq([%w[Environment Service], %w[Environment Service Operation]])
      expect(dimension_sets('AiApiCalls')).to eq([%w[Environment Service Operation ResponseType]])
    end

    it 'preserves every supported operation and response type' do
      described_class::OPERATIONS.product(described_class::RESPONSE_TYPES).each do |operation, response_type|
        expect(record_operation('api_call_completed', operation:, response_type:)).to include('Operation' => operation, 'ResponseType' => response_type, 'AiApiCalls' => 1)
      end
    end

    it 'never exposes arbitrary labels or request data in metrics' do
      result = record_operation('api_call_completed', operation: 'user-input', response_type: 'user-input', request_id: 'secret', effective_query: 'secret', error_message: 'secret', model: 'secret')

      expect(result).to include('Operation' => 'other', 'ResponseType' => 'other')
      expect(result.to_json).not_to include('user-input', 'secret')
      expect(record_operation('retrieval_leg_completed', leg: 'user-input', status: 'success')).to include('Leg' => 'other')
      expect(record_operation('retrieval_leg_completed', duration_ms: 1)).to include('Leg' => 'unknown')
    end

    it 'does not emit superseded counters without dashboard consumers' do
      expect(described_class::METRIC_NAMES).not_to include('InteractiveSearchErrors', 'DuplicateGuardFailOpen')
      expect(record_operation('search_completed', search_type: 'interactive', final_result_type: 'error')).not_to have_key('InteractiveSearchErrors')
      expect(record_operation('duplicate_question_guard_checked', reason: 'validator_unparseable', suspicious: true)).not_to have_key('DuplicateGuardFailOpen')
    end

    it 'records terminal health samples for both guided search types without changing existing latency rollups' do
      %w[interactive internal].each do |search_type|
        %w[answers questions error].each do |outcome|
          result = record_operation('search_completed', search_type:, final_result_type: outcome, total_duration_ms: 1250)
          expect(result).to include('GuidedSearchErrors' => outcome == 'error' ? 1 : 0, 'GuidedSearchOutcomes' => 1, 'GuidedOutcome' => outcome, 'GuidedSearchDuration' => 1.25, 'SearchDuration' => 1.25)
          expect(dimension_sets('GuidedSearchErrors')).to eq([%w[Environment Service]])
          expect(dimension_sets('GuidedSearchDuration')).to eq([%w[Environment Service]])
          expect(dimension_sets('GuidedSearchOutcomes')).to eq([%w[Environment Service GuidedOutcome]])
          expect(dimension_sets('SearchDuration')).to eq([%w[Environment Service]])
        end
        result = record_operation('search_failed', search_type:, total_duration_ms: 500)
        expect(result).to include('GuidedSearchErrors' => 1, 'GuidedSearchOutcomes' => 1, 'GuidedOutcome' => 'hard_failure')
        expect(result).not_to have_key('GuidedSearchDuration')
      end
    end

    it 'keeps classic, evaluation, classification and unrecognised searches out of guided request health' do
      ['classic', 'evaluation', 'classification', 'user-input', nil].each do |search_type|
        %w[search_completed search_failed].each do |name|
          result = record_operation(name, search_type:, final_result_type: 'error', total_duration_ms: 100)
          expect(result.keys.grep(/Guided/)).to be_empty
        end
      end
    end

    it 'bounds guided outcomes without treating an unrecognised result as a confirmed success' do
      result = record_operation('search_completed', search_type: :internal, final_result_type: 'sensitive arbitrary response')
      expect(result).to include('GuidedOutcome' => 'other', 'GuidedSearchErrors' => 0)
      expect(result.to_json).not_to include('sensitive arbitrary response')
      expect(record_operation('search_completed', search_type: 'interactive')).to include('GuidedOutcome' => 'unknown')
      expect(record_operation('search_completed', search_type: 'interactive', total_duration_ms: -1)).not_to have_key('GuidedSearchDuration')
    end

    it 'uses the same observed terminal events for request errors and their denominator' do
      samples = [
        record_operation('search_completed', search_type: 'interactive', final_result_type: 'questions'),
        record_operation('search_completed', search_type: 'internal', final_result_type: 'answers'),
        record_operation('search_completed', search_type: 'interactive', final_result_type: 'error'),
        record_operation('search_failed', search_type: 'internal'),
      ]
      values = samples.map { |sample| sample.fetch('GuidedSearchErrors') }
      expect(values).to eq([0, 0, 1, 1])
      expect(100.0 * values.sum / values.size).to eq(50.0)
      expect(samples.sum { |sample| sample.fetch('GuidedSearchOutcomes') }).to eq(values.size)
    end

    it 'excludes disabled and non-suspicious checks from the validator-only denominator' do
      %w[guard_disabled not_suspicious].each do |reason|
        expect(record_operation('duplicate_question_guard_checked', reason:, suspicious: false)).to be_nil
      end
      expect(record_operation('duplicate_question_guard_checked', reason: 'validator_unparseable')).to be_nil
      %w[validator_unparseable duplicate new_question].each do |reason|
        result = record_operation('duplicate_question_guard_checked', reason:, suspicious: true)
        expect(result['DuplicateValidatorFailOpen']).to eq(reason == 'validator_unparseable' ? 1 : 0)
        expect(dimension_sets('DuplicateValidatorFailOpen')).to eq([%w[Environment Service]])
      end
    end

    it 'records fallback expansion duration and a separate timeout count' do
      result = record_operation('query_expanded', duration_ms: 3789, query_expansion_failed: true, reason: 'arbitrary model prose')
      expect(result).to include('QueryExpansions' => 1, 'QueryExpansionDuration' => 3.789)
      expect(result).not_to have_key('reason')
      expect(result).not_to have_key('QueryExpansionTimeouts')
      expect(record_operation('query_expansion_timed_out', elapsed_ms: 3779, timeout_ms: 5000)).to include('QueryExpansionTimeouts' => 1)
    end

    it 'records successful and failed leg latency but only successful result counts' do
      described_class::RETRIEVAL_LEGS.each do |leg|
        result = record_operation('retrieval_leg_completed', leg:, status: 'success', duration_ms: 250, result_count: 0)
        expect(result).to include('Leg' => leg, 'RetrievalDuration' => 0.25, 'RetrievalResultCount' => 0, 'RetrievalFailures' => 0)
        expect(dimension_sets('RetrievalDuration')).to eq([%w[Environment Service Leg]])
        expect(dimension_sets('RetrievalResultCount')).to eq([%w[Environment Service Leg]])
        expect(dimension_sets('RetrievalFailures')).to eq([%w[Environment Service Leg]])
        result = record_operation('retrieval_leg_completed', leg:, status: 'error', duration_ms: 500, result_count: 0)
        expect(result).to include('RetrievalDuration' => 0.5, 'RetrievalFailures' => 1)
        expect(result).not_to have_key('RetrievalResultCount')
      end
    end

    it 'does not turn missing or invalid observations into zeroes' do
      [nil, -1, Float::NAN, Float::INFINITY, '100'].each do |invalid|
        expect(record_operation('api_call_completed', duration_ms: invalid)).not_to have_key('AiApiDuration')
        expect(record_operation('query_expanded', duration_ms: invalid)).not_to have_key('QueryExpansionDuration')
        expect(record_operation('retrieval_leg_completed', status: 'success', duration_ms: invalid, result_count: invalid)).not_to have_key('RetrievalResultCount')
      end
      result = record_operation('retrieval_leg_completed', status: 'unexpected', duration_ms: 0, result_count: 10)
      expect(result).to include('RetrievalDuration' => 0.0)
      expect(result).not_to have_key('RetrievalFailures')
      expect(result).not_to have_key('RetrievalResultCount')
    end

    it 'emits metric definitions with valid units and bounded dimensions' do
      events = {
        'api_call_completed' => { duration_ms: 100, operation: 'duplicate_question_retry', response_type: 'questions' },
        'query_expanded' => { duration_ms: 100 },
        'query_expansion_timed_out' => {},
        'retrieval_leg_completed' => { leg: 'vector', status: 'success', duration_ms: 100, result_count: 2 },
        'duplicate_question_guard_checked' => { reason: 'validator_unparseable', suspicious: true },
        'search_completed' => payload.merge(search_type: 'interactive'),
      }
      events.each do |name, attributes|
        result = record_operation(name, attributes)
        expect(output.string.bytesize).to be < described_class::MAX_LINE_BYTES
        result.dig('_aws', 'CloudWatchMetrics').each do |definition|
          metric = definition.fetch('Metrics').sole
          expect(described_class::METRIC_NAMES).to include(metric.fetch('Name'))
          expect(metric.fetch('Unit')).to eq(metric.fetch('Name').end_with?('Duration') ? 'Seconds' : 'Count')
          definition.fetch('Dimensions').flatten.each { |dimension| expect(result).to have_key(dimension) }
        end
      end
    end
  end

  it 'drops a failed write instead of raising' do
    failing = instance_double(IO)
    allow(failing).to receive(:write_nonblock).and_raise(IOError)

    expect(described_class.record(event, output: failing, environment: 'production', service: 'uk', now:)).to be(false)
  end

  it 'drops a blocked, short, or oversized write' do
    blocked = instance_double(IO)
    allow(blocked).to receive(:write_nonblock).and_return(:wait_writable)
    expect(described_class.record(event, output: blocked, environment: 'production', service: 'uk', now:)).to be(false)

    short = instance_double(IO)
    allow(short).to receive(:write_nonblock).and_return(1)
    expect(described_class.record(event, output: short, environment: 'production', service: 'uk', now:)).to be(false)

    allow(JSON).to receive(:generate).and_return('x' * described_class::MAX_LINE_BYTES)
    expect(output).not_to receive(:write_nonblock)
    expect(record).to be(false)
  end

  it 'subscribes to search notifications and can be removed' do
    buffer = StringIO.new
    described_class.subscribe!(output: buffer)
    ActiveSupport::Notifications.instrument('query_expanded.search', {})
    described_class.unsubscribe!
    ActiveSupport::Notifications.instrument('query_expanded.search', {})

    expect(buffer.string.lines.size).to eq(1)
  ensure
    described_class.unsubscribe!
  end

  it 'keeps one subscription when the class state is discarded' do
    buffer = StringIO.new
    described_class.subscribe!(output: buffer)
    expect(Rails.application.config.x.search_metrics_subscriber).to be_present
    described_class.singleton_class.remove_instance_variable(:@subscriber) if described_class.singleton_class.instance_variable_defined?(:@subscriber)

    described_class.subscribe!(output: buffer)
    ActiveSupport::Notifications.instrument('query_expanded.search', {})

    expect(buffer.string.lines.size).to eq(1)
  ensure
    described_class.unsubscribe!
  end
end
