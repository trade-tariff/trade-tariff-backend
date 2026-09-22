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

  it 'keeps the failure-excluded cohort off this dashboard' do
    expect(dashboard).to include('does not remove an earlier count')
    expect(dashboard).to include('A gap is missing telemetry, not zero traffic')
    expect(dashboard).to include('Exact classic matches are not empty commodity results')
  end
end
