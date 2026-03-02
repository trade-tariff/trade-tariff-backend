RSpec.describe EmbeddingService do
  subject(:service) { described_class.new }

  let(:api_base_url) { 'https://api.openai.com/v1' }

  before { described_class.reset_client! }

  describe '#embed' do
    let(:embedding) { Array.new(1536) { rand(-1.0..1.0) } }
    let(:response_body) do
      {
        'data' => [{ 'index' => 0, 'embedding' => embedding }],
      }
    end

    before do
      stub_request(:post, "#{api_base_url}/embeddings")
        .to_return(status: 200, body: response_body.to_json, headers: { 'Content-Type' => 'application/json' })
    end

    it 'returns a single embedding vector' do
      result = service.embed('Live horses')
      expect(result).to eq(embedding)
    end

    it 'sends the correct model' do
      service.embed('Live horses')

      expect(WebMock).to have_requested(:post, "#{api_base_url}/embeddings")
        .with(body: hash_including('model' => 'text-embedding-3-small'))
    end

    it 'sends the text as input array' do
      service.embed('Live horses')

      expect(WebMock).to have_requested(:post, "#{api_base_url}/embeddings")
        .with(body: hash_including('input' => ['Live horses']))
    end
  end

  describe '#embed_batch' do
    context 'with a small batch' do
      let(:embeddings) { Array.new(3) { Array.new(1536) { rand(-1.0..1.0) } } }
      let(:response_body) do
        {
          'data' => embeddings.each_with_index.map { |emb, i| { 'index' => i, 'embedding' => emb } },
        }
      end

      before do
        stub_request(:post, "#{api_base_url}/embeddings")
          .to_return(status: 200, body: response_body.to_json, headers: { 'Content-Type' => 'application/json' })
      end

      it 'returns embeddings for all texts' do
        result = service.embed_batch(%w[one two three])
        expect(result.size).to eq(3)
      end

      it 'preserves order based on index' do
        result = service.embed_batch(%w[one two three])
        expect(result).to eq(embeddings)
      end
    end

    context 'when response indices are out of order' do
      let(:embeddings) { Array.new(2) { Array.new(1536) { rand(-1.0..1.0) } } }
      let(:response_body) do
        {
          'data' => [
            { 'index' => 1, 'embedding' => embeddings[1] },
            { 'index' => 0, 'embedding' => embeddings[0] },
          ],
        }
      end

      before do
        stub_request(:post, "#{api_base_url}/embeddings")
          .to_return(status: 200, body: response_body.to_json, headers: { 'Content-Type' => 'application/json' })
      end

      it 'sorts by index to match input order' do
        result = service.embed_batch(%w[first second])
        expect(result).to eq(embeddings)
      end
    end

    context 'with a batch larger than BATCH_SIZE' do
      let(:embedding) { Array.new(1536) { 0.1 } }

      before do
        stub_request(:post, "#{api_base_url}/embeddings")
          .to_return do |request|
            body = JSON.parse(request.body)
            count = body['input'].size
            data = Array.new(count) { |i| { 'index' => i, 'embedding' => embedding } }
            { status: 200, body: { 'data' => data }.to_json, headers: { 'Content-Type' => 'application/json' } }
          end
      end

      it 'chunks into multiple API calls' do
        texts = Array.new(150) { |i| "text #{i}" }
        result = service.embed_batch(texts)

        expect(result.size).to eq(150)
        expect(WebMock).to have_requested(:post, "#{api_base_url}/embeddings").times(2)
      end
    end

    context 'when the API returns a retryable error then succeeds' do
      let(:embedding) { Array.new(1536) { 0.1 } }
      let(:success_body) do
        { 'data' => [{ 'index' => 0, 'embedding' => embedding }] }
      end

      before do
        stub_request(:post, "#{api_base_url}/embeddings")
          .to_return(status: 500, body: { error: 'Internal Server Error' }.to_json, headers: { 'Content-Type' => 'application/json' })
          .then
          .to_return(status: 200, body: success_body.to_json, headers: { 'Content-Type' => 'application/json' })

        allow(Kernel).to receive(:sleep)
      end

      it 'retries and returns the embedding' do
        result = service.embed_batch(%w[test])
        expect(result).to eq([embedding])
        expect(WebMock).to have_requested(:post, "#{api_base_url}/embeddings").times(2)
      end
    end

    context 'when the API returns a retryable error repeatedly' do
      before do
        stub_request(:post, "#{api_base_url}/embeddings")
          .to_return(status: 500, body: { error: 'Internal Server Error' }.to_json, headers: { 'Content-Type' => 'application/json' })

        allow(Kernel).to receive(:sleep)
      end

      it 'raises after exhausting retries' do
        expect { service.embed_batch(%w[test]) }.to raise_error(EmbeddingService::ServerError, /500/)
        expect(WebMock).to have_requested(:post, "#{api_base_url}/embeddings").times(3)
      end
    end

    context 'when a transient SSL error occurs then succeeds' do
      let(:embedding) { Array.new(1536) { 0.1 } }
      let(:success_body) do
        { 'data' => [{ 'index' => 0, 'embedding' => embedding }] }
      end

      before do
        call_count = 0
        stub_request(:post, "#{api_base_url}/embeddings").to_return do
          call_count += 1
          if call_count == 1
            raise Faraday::SSLError, 'SSL_connect returned=1 errno=0 state=error: unexpected eof while reading'
          else
            { status: 200, body: success_body.to_json, headers: { 'Content-Type' => 'application/json' } }
          end
        end

        allow(Kernel).to receive(:sleep)
      end

      it 'retries and returns the embedding' do
        result = service.embed_batch(%w[test])
        expect(result).to eq([embedding])
        expect(WebMock).to have_requested(:post, "#{api_base_url}/embeddings").times(2)
      end
    end

    context 'when SSL errors persist' do
      before do
        stub_request(:post, "#{api_base_url}/embeddings")
          .to_raise(Faraday::SSLError.new('SSL_connect returned=1 errno=0 state=error: unexpected eof while reading'))

        allow(Kernel).to receive(:sleep)
      end

      it 'raises after exhausting retries' do
        expect { service.embed_batch(%w[test]) }.to raise_error(Faraday::SSLError)
        expect(WebMock).to have_requested(:post, "#{api_base_url}/embeddings").times(3)
      end
    end

    context 'when the API returns a non-retryable error' do
      before do
        stub_request(:post, "#{api_base_url}/embeddings")
          .to_return(status: 400, body: { error: 'Bad Request' }.to_json, headers: { 'Content-Type' => 'application/json' })
      end

      it 'raises immediately without retrying' do
        expect { service.embed_batch(%w[test]) }.to raise_error(/EmbeddingService API error: 400/)
        expect(WebMock).to have_requested(:post, "#{api_base_url}/embeddings").times(1)
      end
    end
  end
end
