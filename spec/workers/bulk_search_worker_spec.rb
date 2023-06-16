RSpec.describe BulkSearchWorker, type: :worker do
  subject(:perform) { described_class.new.perform(id) }

  let(:id) { SecureRandom.uuid }

  let(:bulk_search_service) { instance_double(BulkSearchService) }

  before do
    allow(BulkSearchService).to receive(:new).with(id).and_return(bulk_search_service)
  end

  it 'calls BulkSearchService' do
    allow(bulk_search_service).to receive(:call)

    perform

    expect(bulk_search_service).to have_received(:call)
  end

  context 'when BulkSearchService raises an error' do
    let(:id) { result_collection.id }

    let(:result_collection) { BulkSearch::ResultCollection.enqueue(searches) }

    let(:searches) do
      [
        { attributes: { input_description: 'red herring' } },
        { attributes: { input_description: 'white bait' } },
      ]
    end

    before do
      allow(bulk_search_service).to receive(:call).and_raise(StandardError)
    end

    it 'marks BulkSearch::ResultCollection as failed' do
      perform
    rescue StandardError
      expect(BulkSearch::ResultCollection.find(id).status).to eq('failed')
    end

    it { expect { perform }.to raise_error(StandardError) }
  end
end
