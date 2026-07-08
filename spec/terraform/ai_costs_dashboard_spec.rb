# frozen_string_literal: true

RSpec.describe 'AI costs dashboard Terraform' do # rubocop:disable RSpec/DescribeClass
  let(:dashboards_tf) { Rails.root.join('terraform/dashboards.tf').read }

  it 'wires the AI costs dashboard into the dashboard stack' do
    expect(dashboards_tf).to include('resource "aws_cloudwatch_dashboard" "ai_costs"')
    expect(dashboards_tf).to include('dashboard_name = "AICosts-${var.environment}"')
  end

  it 'groups costs and tokens by low-cardinality event kind' do
    expect(dashboards_tf).to include('api_call_failed')
    expect(dashboards_tf).to include('embedding_api_call_failed')
    expect(dashboards_tf).to include('stats sum(total_cost_usd) as total_cost_usd by event_kind')
    expect(dashboards_tf).to include('stats sum(input_tokens) as input_tokens, sum(output_tokens) as output_tokens, sum(total_tokens) as total_tokens by event_kind')
  end

  it 'keeps unknown model pricing visible instead of counting it as zero' do
    expect(dashboards_tf).to include('filter pricing_known = false or not ispresent(total_cost_usd)')
    expect(dashboards_tf).to include('Unknown or High-Cost Events')
  end

  it 'includes recent high-cost event detail' do
    expect(dashboards_tf).to include('fields @timestamp, service, event, event_kind, model, total_tokens, total_cost_usd, pricing_known')
    expect(dashboards_tf).to include('sort total_cost_usd desc, total_tokens desc')
  end
end
