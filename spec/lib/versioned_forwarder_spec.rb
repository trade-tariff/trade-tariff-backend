RSpec.describe VersionedForwarder do
  describe '#call' do
    subject(:call) { described_class.new.call(env) }

    before do
      allow(Rails.application).to receive(:call).and_return([200, {}, %w[OK]])
      allow(TradeTariffBackend).to receive(:service).and_return('uk')
    end

    context 'when the service is specified and no format extension' do
      let(:env) do
        {
          'PATH_INFO' => '/uk/api/v2/sections',
          'REQUEST_PATH' => '/uk/api/v2/sections',
          'action_dispatch.request.path_parameters' => {
            service: 'uk',
            version: '2',
            path: 'sections',
          },
        }
      end

      it 'transforms the environment correctly' do
        call
        expect(env).to include(
          'action_dispatch.old-path' => '/uk/api/v2/sections',
          'PATH_INFO' => '/uk/api/sections',
          'HTTP_ACCEPT' => 'application/vnd.hmrc.2.0+json',
          'action_dispatch.path-transformed' => true,
        )
      end

      it 'calls Rails application with transformed env' do
        call
        expect(Rails.application).to have_received(:call).with(env)
      end
    end

    context 'when the service is not specified and no format extension' do
      let(:env) do
        {
          'PATH_INFO' => '/api/v2/sections',
          'REQUEST_PATH' => '/api/v2/sections',
          'action_dispatch.request.path_parameters' => {
            version: '2',
            path: 'sections',
          },
        }
      end

      it 'transforms the environment correctly' do
        call
        expect(env).to include(
          'action_dispatch.old-path' => '/api/v2/sections',
          'PATH_INFO' => '/uk/api/sections',
          'HTTP_ACCEPT' => 'application/vnd.hmrc.2.0+json',
          'action_dispatch.path-transformed' => true,
        )
      end

      it 'calls Rails application with transformed env' do
        call
        expect(Rails.application).to have_received(:call).with(env)
      end
    end

    context 'when the service is specified and with .xml format extension' do
      let(:env) do
        {
          'PATH_INFO' => '/uk/api/v2/exchange_rates/files/monthly_xml_2025-8.xml',
          'REQUEST_PATH' => '/uk/api/v2/exchange_rates/files/monthly_xml_2025-8.xml',
          'action_dispatch.request.path_parameters' => {
            service: 'uk',
            version: '2',
            path: 'exchange_rates/files/monthly_xml_2025-8',
          },
        }
      end

      it 'transforms the environment correctly' do
        call
        expect(env).to include(
          'action_dispatch.old-path' => '/uk/api/v2/exchange_rates/files/monthly_xml_2025-8.xml',
          'PATH_INFO' => '/uk/api/exchange_rates/files/monthly_xml_2025-8.xml',
          'HTTP_ACCEPT' => 'application/vnd.hmrc.2.0+xml',
          'action_dispatch.path-transformed' => true,
        )
      end

      it 'calls Rails application with transformed env' do
        call
        expect(Rails.application).to have_received(:call).with(env)
      end
    end

    context 'when the service is not specified and with .xml format extension' do
      let(:env) do
        {
          'PATH_INFO' => '/api/v2/exchange_rates/files/monthly_xml_2025-8.xml',
          'REQUEST_PATH' => '/api/v2/exchange_rates/files/monthly_xml_2025-8.xml',
          'action_dispatch.request.path_parameters' => {
            version: '2',
            path: 'exchange_rates/files/monthly_xml_2025-8',
          },
        }
      end

      it 'transforms the environment correctly' do
        call
        expect(env).to include(
          'action_dispatch.old-path' => '/api/v2/exchange_rates/files/monthly_xml_2025-8.xml',
          'PATH_INFO' => '/uk/api/exchange_rates/files/monthly_xml_2025-8.xml',
          'HTTP_ACCEPT' => 'application/vnd.hmrc.2.0+xml',
          'action_dispatch.path-transformed' => true,
        )
      end

      it 'calls Rails application with transformed env' do
        call
        expect(Rails.application).to have_received(:call).with(env)
      end
    end

    context 'when the service is specified and with .csv format extension' do
      let(:env) do
        {
          'PATH_INFO' => '/uk/api/v2/exchange_rates/files/monthly_csv_2025-8.csv',
          'REQUEST_PATH' => '/uk/api/v2/exchange_rates/files/monthly_csv_2025-8.csv',
          'action_dispatch.request.path_parameters' => {
            service: 'uk',
            version: '2',
            path: 'exchange_rates/files/monthly_csv_2025-8',
          },
        }
      end

      it 'transforms the environment correctly' do
        call
        expect(env).to include(
          'action_dispatch.old-path' => '/uk/api/v2/exchange_rates/files/monthly_csv_2025-8.csv',
          'PATH_INFO' => '/uk/api/exchange_rates/files/monthly_csv_2025-8.csv',
          'HTTP_ACCEPT' => 'application/vnd.hmrc.2.0+csv',
          'action_dispatch.path-transformed' => true,
        )
      end

      it 'calls Rails application with transformed env' do
        call
        expect(Rails.application).to have_received(:call).with(env)
      end
    end

    context 'when the service is not specified and with .csv format extension' do
      let(:env) do
        {
          'PATH_INFO' => '/api/v2/exchange_rates/files/monthly_csv_2025-8.csv',
          'REQUEST_PATH' => '/api/v2/exchange_rates/files/monthly_csv_2025-8.csv',
          'action_dispatch.request.path_parameters' => {
            version: '2',
            path: 'exchange_rates/files/monthly_csv_2025-8',
          },
        }
      end

      it 'transforms the environment correctly' do
        call
        expect(env).to include(
          'action_dispatch.old-path' => '/api/v2/exchange_rates/files/monthly_csv_2025-8.csv',
          'PATH_INFO' => '/uk/api/exchange_rates/files/monthly_csv_2025-8.csv',
          'HTTP_ACCEPT' => 'application/vnd.hmrc.2.0+csv',
          'action_dispatch.path-transformed' => true,
        )
      end

      it 'calls Rails application with transformed env' do
        call
        expect(Rails.application).to have_received(:call).with(env)
      end
    end

    context 'when the service is specified and with .atom format extension' do
      let(:env) do
        {
          'PATH_INFO' => '/uk/api/v2/changes.atom',
          'REQUEST_PATH' => '/uk/api/v2/changes.atom',
          'action_dispatch.request.path_parameters' => {
            service: 'uk',
            version: '2',
            path: 'changes',
          },
        }
      end

      it 'transforms the environment correctly' do
        call
        expect(env).to include(
          'action_dispatch.old-path' => '/uk/api/v2/changes.atom',
          'PATH_INFO' => '/uk/api/changes.atom',
          'HTTP_ACCEPT' => 'application/vnd.hmrc.2.0+atom',
          'action_dispatch.path-transformed' => true,
        )
      end

      it 'calls Rails application with transformed env' do
        call
        expect(Rails.application).to have_received(:call).with(env)
      end
    end

    context 'when the service is not specified and with .atom format extension' do
      let(:env) do
        {
          'PATH_INFO' => '/api/v2/changes.atom',
          'REQUEST_PATH' => '/api/v2/changes.atom',
          'action_dispatch.request.path_parameters' => {
            version: '2',
            path: 'changes',
          },
        }
      end

      it 'transforms the environment correctly' do
        call
        expect(env).to include(
          'action_dispatch.old-path' => '/api/v2/changes.atom',
          'PATH_INFO' => '/uk/api/changes.atom',
          'HTTP_ACCEPT' => 'application/vnd.hmrc.2.0+atom',
          'action_dispatch.path-transformed' => true,
        )
      end

      it 'calls Rails application with transformed env' do
        call
        expect(Rails.application).to have_received(:call).with(env)
      end
    end
  end
end
