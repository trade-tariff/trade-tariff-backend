RSpec.describe VersionedAcceptHeader do
  describe '#matches?' do
    subject(:matches?) { described_class.new(version: '2.0').matches?(request) }

    let(:request) { ActionDispatch::Request.new(Rack::MockRequest.env_for('/', headers)) }

    context 'when the Accept header is present' do
      let(:headers) { { 'HTTP_ACCEPT' => 'application/vnd.hmrc.2.0+json' } }

      it { is_expected.to be true }
    end

    context 'when the Accept header specifies a different format' do
      let(:headers) { { 'HTTP_ACCEPT' => 'application/vnd.hmrc.2.0+csv' } }

      it { is_expected.to be true }
    end

    context 'when the Accept header does not match the versioned format' do
      let(:headers) { { 'HTTP_ACCEPT' => 'application/vnd.hmrc.1.0+json' } }

      it { is_expected.to be false }
    end

    context 'when the Accept header is longer than 255 characters' do
      let(:headers) do
        { 'HTTP_ACCEPT' => 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7' }
      end

      it { is_expected.to be true }
    end

    context 'when the Accept header is a browser default Accept header' do
      let(:headers) { { 'HTTP_ACCEPT' => "#{'a' * 256}application/vnd.hmrc.2.0+json" } }

      it { is_expected.to be true }
    end

    context 'when the Accept header is missing and the configured constraint version is the default' do
      subject(:matches?) { described_class.new(version: '2.0').matches?(request) }

      let(:headers) { {} }

      it { is_expected.to be true }
    end

    context 'when the Accept header is missing and the configured constraint version is not the default' do
      subject(:matches?) { described_class.new(version: '1.0').matches?(request) }

      let(:headers) { {} }

      it { is_expected.to be false }
    end
  end
end
