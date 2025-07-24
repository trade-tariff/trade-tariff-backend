RSpec.describe VersionedAcceptHeader do
  describe '#matches?' do
    subject(:matches?) { described_class.new(version: '1.0').matches?(request) }

    let(:request) { ActionDispatch::Request.new(Rack::MockRequest.env_for('/', headers)) }

    context 'when the Accept header is present' do
      let(:headers) { { 'HTTP_ACCEPT' => 'application/vnd.hmrc.1.0+json' } }

      it { is_expected.to be true }
    end

    context 'when the Accept header does not match the versioned format' do
      let(:headers) { { 'HTTP_ACCEPT' => 'application/vnd.hmrc.2.0+json' } }

      it { is_expected.to be false }
    end

    context 'when the Accept header is missing' do
      let(:headers) { {} }

      it { is_expected.to be false }
    end
  end
end
