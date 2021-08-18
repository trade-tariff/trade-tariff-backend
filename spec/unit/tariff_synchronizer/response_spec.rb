
describe TariffSynchronizer::Response do
  describe '#terminated?' do
    it 'Returns true if response_code is 200 or 404' do
      response = build(:response, response_code: 200)
      expect(response).to be_terminated
    end

    it 'Returns false if response_code is different from 200 or 404' do
      response = build(:response, response_code: 401)
      expect(response).not_to be_terminated
    end
  end

  describe '#retry_count_exceeded!' do
    it 'sets the internal state to exceeded' do
      response = build(:response)
      expect(response.retry_count_exceeded?).to be_falsey
      response.retry_count_exceeded!
      expect(response.retry_count_exceeded?).to be_truthy
    end
  end

  describe '#state' do
    it 'Returns the successful symbol' do
      response = build(:response, response_code: 200, content: 'xyz')
      expect(response.state).to eq(:successful)
    end

    it 'Returns the empty symbol when content is empty' do
      response = build(:response, response_code: 200, content: '')
      expect(response.state).to eq(:empty)
    end

    it 'Returns the exceeded symbol when marked as exceeded' do
      response = build(:response, response_code: 401)
      response.retry_count_exceeded!
      expect(response.state).to eq(:exceeded)
    end

    it 'Returns the not_found symbol when status is 404' do
      response = build(:response, response_code: 404)
      expect(response.state).to eq(:not_found)
    end
  end

  describe '#successful?' do
    it 'returns true for 200 and content' do
      response = build(:response, response_code: 200, content: 'xyz')
      expect(response.send(:successful?)).to be_truthy
    end

    it 'returns false in other cases' do
      response = build(:response, response_code: 404, content: 'xyz')
      expect(response.send(:successful?)).to be_falsey
    end
  end
end
