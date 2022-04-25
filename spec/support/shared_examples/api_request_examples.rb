RSpec.shared_examples 'a successful jsonapi response' do
  it { is_expected.to have_http_status :success }
  it { is_expected.to have_attributes media_type: /json/ }
  it { expect(JSON.parse(subject.body)).to include 'data' }
end

RSpec.shared_examples 'a successful csv response' do
  subject(:do_request) { make_request && response }

  let(:make_request) { get "#{path}.csv" }

  it { expect(do_request.headers['Content-Disposition']).to eq("attachment; filename=#{expected_filename}") }
  it { is_expected.to have_http_status :success }
  it { is_expected.to have_attributes media_type: /csv/ }
  it { expect { CSV.parse(subject.body) }.not_to raise_error }
end
