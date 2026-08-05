# frozen_string_literal: true

RSpec.describe 'search quality dashboard Terraform' do
  let(:module_main_tf) { Rails.root.join('terraform/modules/search_quality_dashboard/main.tf').read }
  let(:overview_main_tf) { Rails.root.join('terraform/modules/search_dashboard/main.tf').read }
  let(:experiment_main_tf) { Rails.root.join('terraform/modules/search_experiment_dashboard/main.tf').read }

  def expand_tf_local(source, name, depth = 0)
    raise "local recursion for #{name}" if depth > 10

    match = source.match(/^\s*#{Regexp.escape(name)}\s*=\s*"((?:\\.|[^"\\])*)"/m)
    raise "missing local #{name}" unless match

    value = match[1].gsub('\\"', '"')
    value.gsub(/\$\{local\.([a-zA-Z0-9_]+)\}/) { expand_tf_local(source, Regexp.last_match(1), depth + 1) }
  end

  def widget_query(source, title)
    block = source[/title\s+=\s+"#{Regexp.escape(title)}".*?query\s+=\s+<<-EOT\n(.*?)\n\s+EOT/m, 1]
    raise "missing widget #{title}" unless block

    block
  end

  it 'defines empty commodity / empty result predicates consistently with overview and experiment dashboards' do
    quality_zero = expand_tf_local(module_main_tf, 'zero_result_condition')
    overview_zero = expand_tf_local(overview_main_tf, 'zero_result_condition')
    experiment_zero = expand_tf_local(experiment_main_tf, 'zero_result_condition')

    expect(quality_zero).to eq(overview_zero)
    expect(quality_zero).to eq(experiment_zero)
    expect(quality_zero).to include('commodity_result_count = 0')
    expect(quality_zero).to include('results_type != "exact_search"')
    expect(quality_zero).to include('not ispresent(commodity_result_count) and result_count = 0')
    expect(quality_zero).to include('search_type = "interactive" or search_type = "internal"')
    expect(quality_zero.count('(')).to eq(quality_zero.count(')'))
  end

  it 'covers classic empty-kind and free-text empty commodity / empty result rate widgets' do
    expect(module_main_tf).to include('Classic Search Outcomes')
    expect(module_main_tf).to include('Classic Empty Kinds')
    expect(module_main_tf).to include('Classic Empty Commodity Rate (non-numeric fuzzy)')
    expect(module_main_tf).to include('Interactive Empty Results Rate (non-numeric)')
    expect(module_main_tf).to include('Empty Commodity / Empty Results Rate (by search type)')
    expect(module_main_tf).to include('classic_non_numeric_fuzzy_condition')
    expect(module_main_tf).to include('interactive_non_numeric_condition')
    expect(module_main_tf).to include('search_type = \\"interactive\\" or search_type = \\"internal\\"')
  end

  it 'keeps free-text guided empty results rate on interactive search types' do
    interactive_rate = widget_query(module_main_tf, 'Interactive Empty Results Rate (non-numeric)')

    expect(interactive_rate).to include('${local.interactive_non_numeric_condition}')
    expect(interactive_rate).to include('${local.interactive_no_results_only}')
    expect(interactive_rate).to include('stats sum(if(${local.interactive_no_results_only}, 1, 0)) * 100.0 / count(*) as no_results_rate_pct by bin(1h)')
    expect(interactive_rate).not_to include('fields')
    expect(interactive_rate).not_to include('@timestamp')
  end

  it 'keeps classic free-text empty commodity rate on non-exact free-text only' do
    classic_rate = widget_query(module_main_tf, 'Classic Empty Commodity Rate (non-numeric fuzzy)')

    expect(classic_rate).to include('${local.classic_non_numeric_fuzzy_condition}')
    expect(classic_rate).to include('${local.classic_empty_commodity_only}')
    expect(classic_rate).to include('stats sum(if(${local.classic_empty_commodity_only}, 1, 0)) * 100.0 / count(*) as empty_commodity_rate_pct by bin(1h)')
    expect(classic_rate).not_to include('@timestamp')
  end

  it 'does not project @timestamp after stats bin for empty commodity / empty result rate widgets' do
    [
      'Classic Empty Rates',
      'Classic Empty Commodity Rate (non-numeric fuzzy)',
      'Interactive Empty Results Rate (non-numeric)',
      'Empty Commodity / Empty Results Rate (by search type)',
    ].each do |title|
      query = widget_query(module_main_tf, title)
      expect(query).to include('bin(1h)')
      expect(query).not_to match(/stats[\s\S]*\|\s*fields[\s\S]*@timestamp/)
    end
  end

  it 'uses shared zero_result_condition for empty commodity / empty result term lists' do
    terms = widget_query(module_main_tf, 'Top 30 Empty Commodity / Empty Result Terms')
    recent = widget_query(module_main_tf, 'Recent Empty Commodity / Empty Result Searches')

    expect(terms).to include('${local.zero_result_condition}')
    expect(recent).to include('${local.zero_result_condition}')
  end
end
