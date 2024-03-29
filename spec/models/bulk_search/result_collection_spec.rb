RSpec.describe BulkSearch::ResultCollection do
  subject(:result_collection) { described_class.new(id:, status:, searches:) }

  let(:searches) do
    [
      { input_description: 'red herring' },
      { input_description: 'white bait' },
    ]
  end
  let(:id) { SecureRandom.uuid }
  let(:status) { BulkSearch::ResultCollection::INITIAL_STATE }

  describe '#as_json' do
    subject(:result_collection) { described_class.new(id:, status:, searches:) }

    let(:searches) do
      [
        {
          number_of_digits: 8,
          input_description: 'red herring',
          search_results: [
            {
              number_of_digits: 6,
              short_code: '950720',
              score: 32.99,
            },
          ],
        },
        {
          number_of_digits: 8,
          input_description: 'white bait',
          search_results: [
            {
              number_of_digits: 6,
              short_code: '160420',
              score: 25.97,
            },
          ],
        },
      ]
    end

    it 'returns a hash representation of the result collection' do
      expected_result = {
        id:,
        status: 'queued',
        searches: [
          {
            input_description: 'red herring',
            search_results: [
              {
                number_of_digits: 6,
                short_code: '950720',
                score: 32.99,
              },
            ],
          },
          {
            input_description: 'white bait',
            search_results: [
              {
                number_of_digits: 6,
                short_code: '160420',
                score: 25.97,
              },
            ],
          },
        ],
      }

      expect(result_collection.as_json).to eq(expected_result)
    end
  end

  describe '#search_ids' do
    it { expect(result_collection.search_ids).to be_present }
  end

  describe '#message' do
    shared_examples_for 'a bulk search result collection message' do |status, message|
      let(:status) { status }

      it { expect(result_collection.message).to eq(message) }
    end

    it_behaves_like 'a bulk search result collection message', BulkSearch::ResultCollection::COMPLETE_STATE, 'Completed'
    it_behaves_like 'a bulk search result collection message', BulkSearch::ResultCollection::PROCESSING_STATE, 'Processing'
    it_behaves_like 'a bulk search result collection message', BulkSearch::ResultCollection::INITIAL_STATE, 'Your bulk search request has been accepted and is now on a queue waiting to be processed'
    it_behaves_like 'a bulk search result collection message', BulkSearch::ResultCollection::FAILED_STATE, 'Failed'
  end

  describe '#http_code' do
    shared_examples_for 'a bulk search result collection http code' do |status, http_code|
      let(:status) { status }

      it { expect(result_collection.http_code).to eq(http_code) }
    end

    it_behaves_like 'a bulk search result collection http code', BulkSearch::ResultCollection::COMPLETE_STATE, 200
    it_behaves_like 'a bulk search result collection http code', BulkSearch::ResultCollection::PROCESSING_STATE, 202
    it_behaves_like 'a bulk search result collection http code', BulkSearch::ResultCollection::INITIAL_STATE, 202
    it_behaves_like 'a bulk search result collection http code', BulkSearch::ResultCollection::FAILED_STATE, 500
  end

  describe '#processing!' do
    it 'updates the status to processing' do
      expect { result_collection.processing! }
        .to change(result_collection, :status)
        .from('queued')
        .to('processing')
    end

    it 'stores the updated status in redis' do
      result_collection.processing!
      updated_result_collection = JSON.parse(
        Zlib::Inflate.inflate(
          TradeTariffBackend.redis.get(result_collection.id),
        ),
      )

      expect(updated_result_collection['status']).to eq('processing')
    end
  end

  describe '#complete!' do
    it 'updates the status to complete' do
      expect { result_collection.complete! }
        .to change(result_collection, :status)
        .from('queued')
        .to('completed')
    end

    it 'stores the updated status in redis' do
      result_collection.complete!
      updated_result_collection = JSON.parse(
        Zlib::Inflate.inflate(
          TradeTariffBackend.redis.get(result_collection.id),
        ),
      )

      expect(updated_result_collection['status']).to eq('completed')
    end
  end

  describe '#failed!' do
    it 'updates the status to failed' do
      expect { result_collection.failed! }
        .to change(result_collection, :status)
        .from('queued')
        .to('failed')
    end

    it 'stores the updated status in redis' do
      result_collection.failed!
      updated_result_collection = JSON.parse(
        Zlib::Inflate.inflate(
          TradeTariffBackend.redis.get(result_collection.id),
        ),
      )

      expect(updated_result_collection['status']).to eq('failed')
    end
  end

  describe '#status' do
    it { expect(result_collection.status).to eq(status.to_s) }
    it { expect(result_collection.status).to be_a(ActiveSupport::StringInquirer) }
  end

  describe '.enqueue' do
    context 'when the bulk searches are valid' do
      let(:searches) do
        [
          { attributes: { input_description: 'red herring' } },
          { attributes: { input_description: 'white bait' } },
        ]
      end

      it 'enqueues a bulk search job' do
        allow(BulkSearchWorker).to receive(:perform_async)
        described_class.enqueue(searches)
        expect(BulkSearchWorker).to have_received(:perform_async).with(match(/^[a-f0-9]{8}-([a-f0-9]{4}-){3}[a-f0-9]{12}$/))
      end

      it 'compresses the result collection' do
        allow(Zlib::Deflate).to receive(:deflate).and_call_original
        described_class.enqueue(searches)
        expect(Zlib::Deflate).to have_received(:deflate).with(anything)
      end

      it 'stores the compressed result collection' do
        allow(TradeTariffBackend.redis).to receive(:set)
        described_class.enqueue(searches)
        expect(TradeTariffBackend.redis).to have_received(:set).with(match(/^[a-f0-9]{8}-([a-f0-9]{4}-){3}[a-f0-9]{12}$/), anything, ex: 7200)
      end

      it 'returns a bulk search result collection' do
        expect(described_class.enqueue(searches)).to be_a(described_class)
      end
    end

    context 'when the bulk searches are invalid' do
      let(:searches) do
        [
          {
            attributes: {
              input_description: 'red herring',
              number_of_digits: 1,
            },
          },
        ]
      end

      it 'does not queue the bulk search job' do
        allow(BulkSearchWorker).to receive(:perform_async)
        described_class.enqueue(searches)
        expect(BulkSearchWorker).not_to have_received(:perform_async)
      end

      it 'does not store the compressed result collection' do
        allow(TradeTariffBackend.redis).to receive(:set)
        described_class.enqueue(searches)
        expect(TradeTariffBackend.redis).not_to have_received(:set).with(match(/^[a-f0-9]{8}-([a-f0-9]{4}-){3}[a-f0-9]{12}$/), anything, ex: 7200)
      end
    end
  end

  describe '.find' do
    let(:id) { SecureRandom.uuid }
    let(:json_blob) do
      {
        id:,
        status:,
        searches: [],
      }.to_json
    end

    context 'when the bulk search job exists' do
      before do
        TradeTariffBackend.redis.set(id, Zlib::Deflate.deflate(json_blob))

        allow(TradeTariffBackend.redis).to receive(:get).and_call_original
      end

      let(:status) { BulkSearch::ResultCollection::COMPLETE_STATE }

      it 'returns a bulk search result collection' do
        expect(described_class.find(id)).to be_a(described_class)
      end

      it 'fetches the compressed result collection' do
        described_class.find(id)
        expect(TradeTariffBackend.redis).to have_received(:get).with(id)
      end
    end

    context 'when the bulk search job does not exist' do
      let(:json_blob) { nil }

      it { expect { described_class.find(id) }.to raise_error(described_class::RecordNotFound) }
    end
  end

  describe '.build' do
    subject(:result_collection) { described_class.build(searches) }

    let(:searches) do
      [
        { attributes: { input_description: 'red herring' } },
        { attributes: { input_description: 'white bait' } },
      ]
    end

    it { expect(result_collection).to be_a(described_class) }
    it { expect(result_collection.id).to match(/^[a-f0-9]{8}-([a-f0-9]{4}-){3}[a-f0-9]{12}$/) }
    it { expect(result_collection.status).to eq(BulkSearch::ResultCollection::INITIAL_STATE.to_s) }
  end
end
