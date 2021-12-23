RSpec.shared_examples 'a successful jsonapi response' do
  it { is_expected.to have_http_status :success }
  it { is_expected.to have_attributes media_type: /json/ }
  it { expect(JSON.parse(subject.body)).to include 'data' }
end

RSpec.shared_examples 'a successful plain json response' do
  it { is_expected.to have_http_status :success }
  it { is_expected.to have_attributes media_type: /json/ }
  it { expect(JSON.parse(subject.body)).not_to include 'data' }
end
