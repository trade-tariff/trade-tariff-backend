RSpec.shared_examples 'a successful jsonapi response' do
  it { is_expected.to have_http_status :success }
  it { is_expected.to have_attributes media_type: /json/ }
  it { expect(JSON.parse(subject.body)).to include 'data' }
end

RSpec.shared_examples 'a successful csv response' do |path|
  subject(:do_request) { make_request && response }

  context 'when using the mime suffix to configure the mime type' do
    let(:make_request) { get "#{path}.csv" }

    it { is_expected.to have_http_status :success }
    it { is_expected.to have_attributes media_type: /csv/ }
    it { expect { CSV.parse(subject.body) }.not_to raise_error }
  end

  context 'when using Accept header to configure the mime type' do
    let(:make_request) { get path, headers: { 'ACCEPT' => 'text/csv' } }

    it { is_expected.to have_http_status :success }
    it { is_expected.to have_attributes media_type: /csv/ }
    it { expect { CSV.parse(subject.body) }.not_to raise_error }
  end
end
