RSpec.describe VersionedForwarder do
  describe '#call' do
    subject(:call) { described_class.new.call(env) }

    before do
      allow(Rails.application).to receive(:call).and_return([200, {}, %w[OK]])
    end

    let(:env) do
      {
        'PATH_INFO' => '/uk/api/v2/sections',
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
end
