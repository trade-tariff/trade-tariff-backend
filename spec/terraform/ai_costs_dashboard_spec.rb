# frozen_string_literal: true

RSpec.describe 'AI costs dashboard Terraform' do # rubocop:disable RSpec/DescribeClass
  let(:dashboards_tf) { Rails.root.join('terraform/dashboards.tf').read }
  let(:module_main_tf) { Rails.root.join('terraform/modules/ai_costs_dashboard/main.tf').read }

  it 'wires the AI costs dashboard into the dashboard stack' do
    expect(dashboards_tf).to include('module "ai_costs_dashboard"')
    expect(dashboards_tf).to include('source = "./modules/ai_costs_dashboard"')
    expect(dashboards_tf).to include('output "ai_costs_dashboard_url"')
  end

  it 'uses a dedicated dashboard module following the existing dashboard pattern' do
    expect(module_main_tf).to include('dashboard_name = var.dashboard_name != null ? var.dashboard_name : "AICosts-${var.environment}"')
    expect(module_main_tf).to include('source         = "SOURCE \'${var.log_group_name}\'"')
    expect(module_main_tf).to include('resource "aws_cloudwatch_dashboard" "ai_costs"')
    expect(module_main_tf).to include('## AI Costs')
  end

  it 'groups total cost by event kind for the selected dashboard time window' do
    aggregate_query = module_main_tf[/title\s+= "Total Cost by Event Kind".*?query\s+= <<-EOT(?<query>.*?)EOT/m, :query]

    expect(module_main_tf).to include('api_call_failed')
    expect(module_main_tf).to include('embedding_api_call_failed')
    expect(aggregate_query).to include('${local.ai_cost_events}')
    expect(aggregate_query).to include('filter ispresent(total_cost_usd)')
    expect(aggregate_query).to include('stats sum(total_cost_usd) as total_cost_usd by event_kind')
    expect(aggregate_query).not_to include('bin(')
  end

  it 'keeps token totals and unknown pricing visible for cost interpretation' do
    expect(module_main_tf).to include('stats sum(input_tokens) as input_tokens, sum(output_tokens) as output_tokens, sum(total_tokens) as total_tokens by event_kind')
    expect(module_main_tf).to include('filter pricing_known = false or not ispresent(total_cost_usd)')
    expect(module_main_tf).to include('sum(total_cost_usd) as partial_cost_usd')
    expect(module_main_tf).to include('Unknown Pricing Events')
  end
end
