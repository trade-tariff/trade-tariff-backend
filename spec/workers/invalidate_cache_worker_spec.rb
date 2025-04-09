RSpec.describe InvalidateCacheWorker, type: :worker do
  subject(:worker) { described_class.new }

  let(:client) { Aws::CloudFront::Client.new(stub_responses: true) }

  let(:base_distribution) do
    {
      id: 'DEFAULT123',
      comment: 'Default CDN',
      arn: 'arn:aws:cloudfront::123456789012:distribution/bar',
      status: 'Deployed',
      last_modified_time: Time.zone.now,
      domain_name: 'foo.cloudfront.net',
      aliases: { quantity: 0, items: [] },
      origins: { quantity: 1, items: [{ id: 'origin1', domain_name: 'example.com' }] },
      default_cache_behavior: { target_origin_id: 'origin1', viewer_protocol_policy: 'allow-all' },
      cache_behaviors: { quantity: 0, items: [] },
      custom_error_responses: { quantity: 0, items: [] },
      price_class: 'PriceClass_All',
      enabled: true,
      viewer_certificate: {},
      restrictions: { geo_restriction: { restriction_type: 'none', quantity: 0 } },
      web_acl_id: '',
      http_version: 'http2',
      is_ipv6_enabled: true,
      staging: false,
    }
  end

  describe '#perform' do
    context 'when the targeted CDN exists' do
      let(:test_distribution) { base_distribution.merge(id: 'TEST123', comment: 'Test CDN') }
      let(:prod_distribution) { base_distribution.merge(id: 'PROD123', comment: 'Production CDN') }

      before do
        client.stub_responses(:list_distributions, {
          distribution_list: {
            marker: '',
            max_items: 100,
            is_truncated: false,
            quantity: 2,
            items: [
              test_distribution,
              prod_distribution,
            ],
          },
        })
        client.stub_responses(:create_invalidation)
      end

      it 'creates an invalidation', skip: 'TODO: Going to investigate this separately' do
        worker.perform(client)
        expect(client.api_requests.pluck(:operation_name)).to include(:list_distributions, :create_invalidation)
      end
    end

    context 'when the targeted CDN does not exist' do
      let(:distribution) { base_distribution.merge(id: 'PROD123', comment: 'Production CDN') }

      before do
        client.stub_responses(
          :list_distributions,
          distribution_list: {
            marker: '',
            max_items: 100,
            is_truncated: false,
            quantity: 1,
            items: [distribution],
          },
        )
      end

      it 'does not create an invalidation' do
        worker.perform(client)

        expect(client.api_requests.pluck(:operation_name)).to eq([:list_distributions])
      end
    end

    context 'when distribution list is empty' do
      before do
        client.stub_responses(
          :list_distributions,
          distribution_list: {
            marker: '',
            max_items: 100,
            is_truncated: false,
            quantity: 1,
            items: [],
          },
        )
      end

      it 'does not create an invalidation' do
        worker.perform(client)
        expect(client.api_requests.pluck(:operation_name)).to eq([:list_distributions])
      end
    end
  end
end
