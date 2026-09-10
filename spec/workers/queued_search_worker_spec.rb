RSpec.describe QueuedSearchWorker, type: :worker do
  subject(:worker) { described_class.new }

  let(:inputs) { { q: 'horse', answers: [{ question: 'Use?', answer: 'Racing', options: '["Racing"]' }] } }
  let(:context) do
    { request_id: 'journey-id', client_id: 'test-client', request_source: 'frontend', experiment: 'async', as_of: '2025-01-02' }
  end
  let(:search) { QueuedSearch.create(params: inputs, context:) }
  let(:service) { instance_double(Api::Internal::SearchService) }
  let(:result) { { data: [], meta: { search_failures: [] } } }

  before do
    allow(Api::Internal::SearchService).to receive(:new).and_return(service)
    allow(service).to receive(:call).and_return(result)
  end

  after { search.delete }

  describe '#perform' do
    it 'runs the search with stored inputs' do
      worker.perform(search.id)

      expect(Api::Internal::SearchService).to have_received(:new).with(inputs.merge(as_of: context[:as_of]).with_indifferent_access)
      expect(search.payload).to include('status' => 'completed', 'result' => result.deep_stringify_keys, 'response_status' => 200)
    end

    it 'keeps the submission date across midnight' do
      id = search.id
      travel_to Time.zone.parse('2025-01-03 01:00:00')

      worker.perform(id)

      expect(Api::Internal::SearchService).to have_received(:new).with(hash_including(as_of: '2025-01-02'))
    end

    it 'exposes running until results are stored' do
      allow(service).to receive(:call) do
        expect(search.payload).to include('status' => 'running')
        expect(search.payload).not_to have_key('result')
        result
      end

      worker.perform(search.id)
    end

    it 'restores request and date context' do
      allow(service).to receive(:call) do
        expect(TradeTariffRequest.attributes).to include(context.except(:as_of))
        expect(TimeMachine.point_in_time.to_date).to eq(Date.new(2025, 1, 2))
        expect(TradeTariffRequest.search_failures).to eq([])
        result
      end

      worker.perform(search.id)
    end

    it 'does not leak context after execution' do
      previous = TradeTariffRequest.attributes.dup
      allow(service).to receive(:call) do
        TradeTariffRequest.record_search_failure(Search::FailureCodes::OPENSEARCH_FAILED)
        result
      end

      worker.perform(search.id)

      expect(TradeTariffRequest.attributes).to eq(previous)
    end

    it 'does not execute duplicate deliveries' do
      worker.perform(search.id)
      worker.perform(search.id)

      expect(service).to have_received(:call).once
    end

    it 'skips missing or expired payloads' do
      search.delete
      worker.perform(search.id)

      expect(service).not_to have_received(:call)
    end

    it 'preserves search validation errors' do
      errors = { errors: [{ title: 'Invalid query' }] }
      allow(service).to receive(:call).and_return(errors)

      worker.perform(search.id)

      expect(search.payload).to include('status' => 'failed', 'response_status' => 422, 'result' => errors.deep_stringify_keys)
    end

    it 'stores safe errors on search failure' do
      allow(service).to receive(:call).and_raise(HybridRetrievalService::AllLegsFailed, 'private provider details')

      expect { worker.perform(search.id) }.to raise_error(HybridRetrievalService::AllLegsFailed)

      expect(search.payload).to include('status' => 'failed', 'response_status' => 500)
      expect(search.payload.to_json).not_to include('private provider details')
    end

    it 'records unexpected errors as failures' do
      allow(service).to receive(:call).and_raise(StandardError, 'private error')

      expect { worker.perform(search.id) }.to raise_error(StandardError, 'private error')

      expect(search.payload).to include('status' => 'failed', 'response_status' => 500)
    end
  end
end
