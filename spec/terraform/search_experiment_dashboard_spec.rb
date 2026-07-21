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
  end

  it 'covers experiment usage, performance, outcomes, questions, searches, and AI costs' do
    expect(module_main_tf).to include('Search Volume and Outcomes')
    expect(module_main_tf).to include('E2E Latency (p50/p90/p99)')
    expect(module_main_tf).to include('Final Result Types')
    expect(module_main_tf).to include('Questions per Search')
    expect(module_main_tf).to include('Top Search Terms')
    expect(module_main_tf).to include('AI Tokens and Cost')
    expect(module_main_tf).to include('Recent Search Journeys')
  end

  it 'is discoverable from the search overview dashboard' do
    expect(search_dashboard_tf).to include('Search Experiments')
    expect(search_dashboard_tf).to include('SearchExperiment-${var.environment}')
  end
end
