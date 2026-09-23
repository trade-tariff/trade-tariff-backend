# frozen_string_literal: true

RSpec.describe 'search overview dashboard Terraform' do
  subject(:dashboard) { Rails.root.join('terraform/modules/search_dashboard/main.tf').read }

  it 'reads TradeTariff/Search metrics instead of scanning logs' do
    widget_types = dashboard.scan(/type\s+=\s+"(\w+)"/).flatten

    expect(widget_types).to include('text', 'metric')
    expect(widget_types - %w[text metric]).to be_empty
    expect(dashboard).not_to include('queryLanguage')
    expect(dashboard).not_to include('DATE_TRUNC')
    expect(dashboard).not_to include('request_exclusion_filter')
    expect(dashboard).to include('MetricName=\"ResultCount\"')
    expect(dashboard).to include('MetricName=\"CommodityResultCount\"')
    expect(dashboard).to include('Outcome=\"completed\"')
    expect(dashboard).to include('{${local.namespace},Environment,Service,SearchType}')
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
