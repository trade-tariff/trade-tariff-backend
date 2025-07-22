RSpec.describe HandleGoodsNomenclature do
  subject(:middleware) { described_class.new(app) }

  let(:app) { ->(env) { [200, env, %w[OK]] } }

  describe '#call' do
    context 'when the request path matches a chapter commodity' do
      let(:original_path) { '/xi/api/commodities/0100000000' }
      let(:env) { Rack::MockRequest.env_for(original_path) }

      it 'transforms the path to chapters with the short code', :aggregate_failures do
        _, updated_env, _response = middleware.call(env)

        expect(updated_env['action_dispatch.old-path']).to eq(original_path)
        expect(updated_env['action_dispatch.path-transformed']).to eq('/xi/api/chapters/01')
        expect(updated_env['PATH_INFO']).to eq('/xi/api/chapters/01')
      end
    end

    context 'when the request path matches a heading commodity' do
      let(:original_path) { '/commodities/1234000000' }
      let(:env) { Rack::MockRequest.env_for(original_path) }

      it 'transforms the path to headings with the short code', :aggregate_failures do
        _, updated_env, _response = middleware.call(env)

        expect(updated_env['action_dispatch.old-path']).to eq(original_path)
        expect(updated_env['action_dispatch.path-transformed']).to eq('/headings/1234')
        expect(updated_env['PATH_INFO']).to eq('/headings/1234')
      end
    end

    context 'when the request path does not match a commodity' do
      let(:original_path) { '/some/other/path' }
      let(:env) { Rack::MockRequest.env_for(original_path) }

      it 'leaves the path unchanged', :aggregate_failures do
        _, updated_env, _response = middleware.call(env)

        expect(updated_env).not_to have_key('action_dispatch.old-path')
        expect(updated_env['PATH_INFO']).to eq(original_path)
      end
    end

    context "when the request path includes 'commodities' but does not match expected pattern" do
      let(:original_path) { '/commodities/invalid' }
      let(:env) { Rack::MockRequest.env_for(original_path) }

      it 'leaves the path unchanged', :aggregate_failures do
        _, updated_env, _response = middleware.call(env)

        expect(updated_env).not_to have_key('action_dispatch.old-path')
        expect(updated_env['PATH_INFO']).to eq(original_path)
      end
    end
  end
end
