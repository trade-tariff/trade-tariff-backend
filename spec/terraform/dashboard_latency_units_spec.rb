require 'rails_helper'

RSpec.describe 'CloudWatch dashboard latency units' do
  dashboard_files = Dir[Rails.root.join('terraform/modules/*_dashboard/main.tf')].freeze

  latency_widgets = dashboard_files.flat_map do |path|
    File.read(path).scan(
      /title\s+= "([^"]+)"(?:(?!title\s+=).)*?query\s+= <<-EOT\n(.*?)\n\s+EOT/m,
    ).filter_map do |title, query|
      [path, title, query] if query.match?(/\| stats .*duration_ms/)
    end
  end

  it 'converts every aggregated millisecond duration to a human-scale unit' do
    aggregate_expressions = latency_widgets.flat_map do |_path, _title, query|
      query.scan(/\b(?:pct|avg|max|min|median)\(([^)]*duration_ms[^)]*)\)/).flatten
    end

    expect(aggregate_expressions).not_to be_empty
    expect(aggregate_expressions).to all(match(%r{/ (?:1000|60000)}))
  end

  it 'states the unit in every latency or duration chart title' do
    titles = latency_widgets.map { |_path, title, _query| title }

    expect(titles).to all(match(/\b(?:seconds|minutes)\b/))
    expect(titles.join("\n")).not_to match(/\((?:ms|s|min)\)/)
  end

  it 'states the unit in every aggregated latency or duration series name' do
    queries = latency_widgets.map { |_path, _title, query| query }

    expect(queries).to all(match(/\bas \w+_(?:seconds|minutes)\b/))
    expect(queries.join("\n")).not_to match(/\bas (?:p50|p90|p99|max|avg|avg_ms|avg_duration_ms)\b/)
  end
end
