# frozen_string_literal: true

RSpec.describe 'search experiment dashboard Terraform' do
  let(:dashboards_tf) { Rails.root.join('terraform/dashboards.tf').read }
  let(:module_main_tf) { Rails.root.join('terraform/modules/search_experiment_dashboard/main.tf').read }
  let(:search_dashboard_tf) { Rails.root.join('terraform/modules/search_dashboard/main.tf').read }

  it 'wires the search experiment dashboard into the dashboard stack' do
    expect(dashboards_tf).to include('module "search_experiment_dashboard"')
    expect(dashboards_tf).to include('source = "./modules/search_experiment_dashboard"')
    expect(dashboards_tf).to include('output "search_experiment_dashboard_url"')
  end

  it 'filters every widget through a visible experiment label variable' do
    expect(module_main_tf).to match(/dashboard_name\s+= var\.dashboard_name != null \? var\.dashboard_name : "SearchExperiment-\$\{var\.environment\}"/)
    expect(module_main_tf).to include('type         = "pattern"')
    expect(module_main_tf).to include('pattern      = "EXPERIMENT_LABEL"')
    expect(module_main_tf).to include('inputType    = "input"')
    expect(module_main_tf).to include('defaultValue = "trstd-trdr"')
    expect(module_main_tf).to include('experiment = \\"EXPERIMENT_LABEL\\"')

    queries = module_main_tf.scan(/query\s+= <<-EOT\n(.*?)\n\s+EOT/m).flatten
    expect(queries).not_to be_empty
    expect(queries).to all(match(/\$\{local\.(?:search|experiment|ai_cost)_filter\}/))
  end

  it 'covers experiment usage, performance, outcomes, questions, searches, and AI costs' do
    expect(module_main_tf).to include('UAT Period Totals')
    expect(module_main_tf).to include('E2E Latency (p50/p90/p99)')
    expect(module_main_tf).to include('Final Result Types')
    expect(module_main_tf).to include('Questions per Search')
    expect(module_main_tf).to include('Top Search Terms')
    expect(module_main_tf).to include('Total AI Cost by Operation')
    expect(module_main_tf).to include('Recent UAT Events')
  end

  it 'explains how to interpret and investigate the production UAT cohort' do
    expect(module_main_tf).to include('Production UAT')
    expect(module_main_tf).to include('Requests are counted, not unique users')
    expect(module_main_tf).to include('Set the dashboard time range to the UAT window')
    expect(module_main_tf).to include('copy the request ID into admin search diagnostics')
    expect(module_main_tf).to include('Recent UAT Events')
    expect(module_main_tf).not_to include('Recent Search Journeys')
  end

  it 'separates period cost and token totals and exposes incomplete pricing' do
    expect(module_main_tf).to include('event in [\\"api_call_completed\\", \\"embedding_api_call_completed\\"]')
    expect(module_main_tf).to include('service = \\"ai_usage\\" and event = \\"embedding_api_call_completed\\"')
    expect(module_main_tf).to include('event_kind = \\"vector_search_query_embedding\\"')
    expect(module_main_tf).to include('if(ispresent(operation), operation, event_kind) as ai_operation')
    expect(module_main_tf).to include('Total AI Cost by Operation')
    expect(module_main_tf).to include('| filter pricing_known')
    expect(module_main_tf).to include('| filter ispresent(total_cost_usd)')
    expect(module_main_tf).to include('stats sum(total_cost_usd) as total_cost_usd by ai_operation, model')
    expect(module_main_tf).to include('AI Token Totals by Operation')
    expect(module_main_tf).to include('sum(input_tokens) as input_tokens')
    expect(module_main_tf).to include('sum(output_tokens) as output_tokens')
    expect(module_main_tf).to include('Unknown Pricing Events')
    expect(module_main_tf).to include('not pricing_known or not ispresent(total_cost_usd)')
    expect(module_main_tf).not_to include('pricing_known = true')
    expect(module_main_tf).not_to include('pricing_known = false')
    expect(module_main_tf).not_to include('AI Tokens and Cost')
  end

  it 'summarises the UAT period and exposes the behaviour needed for diagnosis' do
    expect(module_main_tf).to include('UAT Period Totals')
    expect(module_main_tf).to include('as completed_requests')
    expect(module_main_tf).to include('as hard_failures')
    expect(module_main_tf).to include('as error_outcomes')
    expect(module_main_tf).to include('as zero_result_requests')
    expect(module_main_tf).to include('as selections')
    expect(module_main_tf).to include('Questions and Answers')
    expect(module_main_tf).to include('event in ["question_returned", "answer_returned"]')
    expect(module_main_tf).to include('details.questions.0.question as question')
    expect(module_main_tf).to include('details.answers.0.commodity_code as top_commodity_code')
    expect(module_main_tf).to include('details.answers.0.confidence as top_confidence')
    expect(module_main_tf).to include('Selected Results')
    expect(module_main_tf).to include('goods_nomenclature_item_id')
    expect(module_main_tf).to include('Top Zero-Result Terms')
  end

  it 'shows provider latency by operation so slow requests can be diagnosed' do
    expect(module_main_tf).to include('AI API Latency (p50/p90/p99)')
    expect(module_main_tf).to include('pct(duration_ms, 50) as p50')
    expect(module_main_tf).to include('by operation, bin(1h)')
  end

  it 'uses renderable hourly request volume series' do
    expect(module_main_tf).to include('sum(if(event = "search_completed", 1, 0)) as completed_requests')
    expect(module_main_tf).to include('sum(if(event = "search_failed", 1, 0)) as failed_requests')
    expect(module_main_tf).to include('as failed_requests by search_type, bin(1h)')
    expect(module_main_tf).not_to include('stats count(*) as searches by event, search_type, bin(1h)')
  end

  it 'uses a single outcome dimension for the result-type pie chart' do
    expect(module_main_tf).to include('stats count(*) as searches by final_result_type')
    expect(module_main_tf).not_to include('by search_type, results_type, final_result_type')
  end

  it 'is discoverable from the search overview dashboard' do
    expect(search_dashboard_tf).to include('Search Experiments')
    expect(search_dashboard_tf).to include('SearchExperiment-${var.environment}')
  end
end
