RSpec.describe 'excess query counts', type: :request do
  before { allow(Sentry).to receive(:capture_message).and_return true }

  let(:get_page) { get api_heading_path(heading, format: :json) }

  let :heading do
    create(:commodity,
           :with_chapter,
           :with_heading,
           :with_description,
           :non_declarable).reload.heading
  end

  context 'with request count under threshold' do
    before do
      allow(::SequelRails::Railties::LogSubscriber).to receive(:count).and_return 10

      get_page
    end

    it 'does not raise an exception' do
      expect(response).to have_http_status :ok
    end

    it 'does not notify sentry' do
      expect(Sentry).not_to have_received :capture_message
    end
  end

  context 'with request count over threshold' do
    before { allow(::SequelRails::Railties::LogSubscriber).to receive(:count).and_return 21 }

    context 'with exceptions mode' do
      before do
        allow(QueryCountChecker).to receive(:new).and_return \
          QueryCountChecker.new(20, raise_exception: true)

        get_page
      end

      it { expect(response).to have_http_status :internal_server_error }
    end

    context 'with alerting mode' do
      before do
        allow(QueryCountChecker).to receive(:new).and_return \
          QueryCountChecker.new(20, raise_exception: false)

        get_page
      end

      it 'notifies sentry' do
        expect(Sentry).to have_received(:capture_message).with \
          'Excess queries detected: 21 (limit: 20)'
      end
    end
  end
end
