# frozen_string_literal: true

RSpec.describe 'search overview dashboard Terraform' do
  subject(:dashboard) { Rails.root.join('terraform/modules/search_dashboard/main.tf').read }

  it 'keeps operational trends on metrics with one log query for experiment activity' do
    widget_types = dashboard.scan(/type\s+=\s+"(\w+)"/).flatten

    expect(widget_types).to include('text', 'metric')
    expect(widget_types.count('log')).to eq(1)
    expect(widget_types - %w[text metric log]).to be_empty
    expect(dashboard).not_to include('queryLanguage')
    expect(dashboard).not_to include('DATE_TRUNC')
    expect(dashboard).not_to include('request_exclusion_filter')
    expect(dashboard).to include('MetricName=\"ResultCount\"')
    expect(dashboard).to include('MetricName=\"CommodityResultCount\"')
    expect(dashboard).to include('Outcome=\"completed\"')
    expect(dashboard).to include('{${local.namespace},Environment,Service,SearchType}')
  end

  it 'counts distinct labelled browser sessions with visible pages rather than requests or steps' do
    expect(dashboard).to include('event = "guided_search.journey" and schema_version = 1 and outcome = "page_visible"')
    expect(dashboard).to include('browser_session_id like /^v1:[0-9a-f]{64}$/')
    expect(dashboard).to include('experiment like /\S/')
    expect(dashboard).to include('stats count_distinct(browser_session_id) as estimated_active_browser_sessions by experiment')
    expect(dashboard).to include('sort estimated_active_browser_sessions desc', 'limit 30')
    expect(dashboard).to include('sessions can appear under multiple labels', 'not people or all enrolments')
    expect(dashboard).not_to include('by experiment, bin(')
  end

  it 'keeps essential caveats short and links to the counting definitions' do
    expect(dashboard).to include('gaps are not zero')
    expect(dashboard).to include('include degraded searches')
    expect(dashboard).to include('docs/search-dashboards.md')
    definitions = Rails.root.join('docs/search-dashboards.md').read
    expect(definitions).to include('A later failure does not remove an earlier count')
    expect(definitions).to include('Exact classic matches are excluded')
  end
end
