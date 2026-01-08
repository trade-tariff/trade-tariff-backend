RSpec.shared_examples 'a successful jsonapi response' do |data_length|
  it { is_expected.to have_http_status :success }
  it { is_expected.to have_attributes media_type: /json/ }
  it { expect(JSON.parse(subject.body)).to include 'data' }

  unless data_length.nil?
    it { expect(JSON.parse(subject.body)['data']).to have_attributes length: data_length }
  end
end

RSpec.shared_examples 'a successful csv response' do
  subject(:do_request) { make_request && response }

  let(:make_request) { api_get "#{path}.csv" }

  it { expect(do_request.headers['Content-Disposition']).to eq("attachment; filename=#{expected_filename}") }
  it { is_expected.to have_http_status :success }
  it { is_expected.to have_attributes media_type: /csv/ }
  it { expect { CSV.parse(subject.body) }.not_to raise_error }
end

RSpec.shared_examples 'a unauthorised response for invalid bearer token' do
  it { is_expected.to have_http_status :unauthorized }
  it { is_expected.to have_attributes message: 'Unauthorized' }
  it { expect(subject.body).to eq('{"message":"No bearer token was provided"}') }
end

RSpec.shared_examples 'a unauthorised public user response for invalid bearer token' do
  it { is_expected.to have_http_status :unauthorized }
  it { is_expected.to have_attributes message: 'Unauthorized' }

  it 'returns JSON:API error response' do
    subject
    expect(response.parsed_body).to eq({ 'errors' => [{ 'code' => 'missing_token', 'detail' => 'No bearer token was provided' }] })
  end
end
