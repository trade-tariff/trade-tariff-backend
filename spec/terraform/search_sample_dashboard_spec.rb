# frozen_string_literal: true

RSpec.describe 'search sample dashboard Terraform' do
  let(:dashboards_tf) { Rails.root.join('terraform/dashboards.tf').read }
  let(:module_main_tf) { Rails.root.join('terraform/modules/search_sample_dashboard/main.tf').read }
  let(:search_dashboard_tf) { Rails.root.join('terraform/modules/search_dashboard/main.tf').read }
  let(:experiment_dashboard_tf) { Rails.root.join('terraform/modules/search_experiment_dashboard/main.tf').read }

  it 'wires the search sample dashboard into the dashboard stack' do
    expect(dashboards_tf).to include('module "search_sample_dashboard"')
    expect(dashboards_tf).to include('source = "./modules/search_sample_dashboard"')
    expect(dashboards_tf).to include('output "search_sample_dashboard_url"')
  end

  it 'uses a dedicated dashboard module following the existing dashboard pattern' do
    expect(module_main_tf).to match(/dashboard_name\s+= var\.dashboard_name != null \? var\.dashboard_name : "SearchSample-\$\{var\.environment\}"/)
    expect(module_main_tf).to include("SOURCE '${var.log_group_name}'")
    expect(module_main_tf).to include('resource "aws_cloudwatch_dashboard" "search_sample"')
    expect(module_main_tf).to include('## Trade Tariff Search Sample')
  end

  it 'compares tenpct with unlabelled frontend control and keeps URL enrolments separate' do
    expect(module_main_tf).to include('experiment = \\"tenpct\\"')
    expect(module_main_tf).to include('trstd-trdr')
    expect(module_main_tf).to include('filter cohort = \\"tenpct\\" or cohort = \\"control\\"')
    expect(module_main_tf).to include('request_source = \\"frontend\\"')
    expect(module_main_tf).to include('stats earliest(@timestamp) as requested_at by request_id, cohort')
    expect(module_main_tf).not_to include('EXPERIMENT_LABEL')
  end

  it 'does not query guided sessions for control traffic' do
    sessions_query = widget_query('Estimated Sample Browser Sessions')
    dont_know_query = widget_query("I Don't Know Usage in Sample")

    expect(sessions_query).to include('filter experiment = "tenpct"')
    expect(sessions_query).not_to include('cohort = "control"')
    expect(dont_know_query).to include('filter experiment = "tenpct"')
    expect(dont_know_query).not_to include('cohort = "control"')
  end

  it 'collapses duplicate request IDs before volume and rate totals' do
    expect(widget_query('Completed Searches by Cohort and Type')).to include('datefloor(requested_at, 1h)')
    expect(widget_query('Empty Result Rate by Cohort and Type')).to include('empty_result_rate_percent')
    expect(module_main_tf).to include('classic_selectable_condition')
    expect(widget_query('Selection Rate by Cohort')).to include('${local.selectable_condition}')
    expect(widget_query('Selection Rate by Cohort')).to include('filter selectable = 1')
    expect(widget_query('Selection Rate by Cohort')).to include('max(if(event = "search_completed", experiment, "")) as experiment by request_id')
    expect(widget_query('Selection Rate by Cohort')).to include('selection_rate_percent')
    expect(widget_query('Priced AI Cost by Cohort')).to include('filter request_source = "frontend"')
    expect(widget_query('Recent Sample and Control Events')).to include('| limit 20')
    expect(widget_query('Recent Sample and Control Events')).not_to include('query')
  end

  it 'is discoverable from the search overview and experiment dashboards' do
    expect(search_dashboard_tf).to include('Search Sample')
    expect(search_dashboard_tf).to include('SearchSample-${var.environment}')
    expect(experiment_dashboard_tf).to include('Search Sample')
    expect(experiment_dashboard_tf).to include('SearchSample-${var.environment}')
  end

  def widget_query(title)
    module_main_tf.match(/title\s+= "#{Regexp.escape(title)}".*?query\s+= <<-EOT\n(.*?)\n\s+EOT/m).then do |match|
      expect(match).to be_present
      match[1]
    end
  end
end
