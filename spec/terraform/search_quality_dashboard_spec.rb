# frozen_string_literal: true

RSpec.describe 'search quality dashboard Terraform' do
  let(:module_main_tf) { Rails.root.join('terraform/modules/search_quality_dashboard/main.tf').read }
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

  def expect_one_title(title)
    expect(module_main_tf.scan(/title\s+=\s+"#{Regexp.escape(title)}"/).size).to eq(1)
  end

  def evaluate_guard_case(expression, record)
    CwliExpression.new(expression, record).parse_case
  end

  def evaluate_guard_condition(expression, record)
    CwliExpression.new(expression, record).parse_or
  end

  it 'defines empty commodity / empty result predicates consistently with the experiment dashboard' do
    quality_zero = expand_tf_local(module_main_tf, 'zero_result_condition')
    experiment_zero = expand_tf_local(experiment_main_tf, 'zero_result_condition')

    expect(quality_zero).to eq(experiment_zero)
    expect(quality_zero).to include('commodity_result_count = 0')
    expect(quality_zero).to include('results_type != "exact_search"')
    expect(quality_zero).to include('not ispresent(commodity_result_count) and result_count = 0')
    expect(quality_zero).to include('search_type = "interactive" or search_type = "internal"')
    expect(quality_zero.count('(')).to eq(quality_zero.count(')'))
  end

  it 'covers classic empty-kind and free-text empty commodity / empty result rate widgets' do
    [
      'Classic completed events by outcome',
      'Classic empty events: no results versus other hits only',
      'Classic free-text non-exact empty commodity %, hourly',
      'Guided free-text no-results %, hourly',
      'Empty events, % of classic, interactive and internal completions, hourly',
    ].each { |title| expect_one_title(title) }
    expect(module_main_tf).to include('classic_non_numeric_fuzzy_condition')
    expect(module_main_tf).to include('interactive_non_numeric_condition')
    expect(module_main_tf).to include('search_type = \\"interactive\\" or search_type = \\"internal\\"')
  end

  it 'keeps free-text guided empty results rate on interactive search types' do
    interactive_rate = widget_query(module_main_tf, 'Guided free-text no-results %, hourly')

    expect(interactive_rate).to include('${local.interactive_non_numeric_condition}')
    expect(interactive_rate).to include('${local.interactive_no_results_only}')
    expect(interactive_rate).to include('stats sum(if(${local.interactive_no_results_only}, 1, 0)) * 100.0 / count(*) as no_results_rate_pct by bin(1h)')
    expect(interactive_rate).not_to include('fields')
    expect(interactive_rate).not_to include('@timestamp')
  end

  it 'keeps classic free-text empty commodity rate on non-exact free-text only' do
    classic_rate = widget_query(module_main_tf, 'Classic free-text non-exact empty commodity %, hourly')

    expect(classic_rate).to include('${local.classic_non_numeric_fuzzy_condition}')
    expect(classic_rate).to include('${local.classic_empty_commodity_only}')
    expect(classic_rate).to include('stats sum(if(${local.classic_empty_commodity_only}, 1, 0)) * 100.0 / count(*) as empty_commodity_rate_pct by bin(1h)')
    expect(classic_rate).not_to include('@timestamp')
  end

  it 'does not project @timestamp after stats bin for empty commodity / empty result rate widgets' do
    [
      'Classic empty events, % of all completions, hourly',
      'Classic free-text non-exact empty commodity %, hourly',
      'Guided free-text no-results %, hourly',
      'Empty events, % of classic, interactive and internal completions, hourly',
    ].each do |title|
      query = widget_query(module_main_tf, title)
      expect(query).to include('bin(1h)')
      expect(query).not_to match(/stats[\s\S]*\|\s*fields[\s\S]*@timestamp/)
    end
  end

  it 'uses shared zero_result_condition for empty commodity / empty result term lists' do
    terms = widget_query(module_main_tf, 'Top 30 empty queries, including code lookups')
    recent = widget_query(module_main_tf, 'Latest 30 empty events')

    expect(terms).to include('${local.zero_result_condition}')
    expect(recent).to include('${local.zero_result_condition}')
    expect(terms).to include('"Missing query"')
    expect(terms).to include('"Blank or whitespace query"')
    expect(recent).to include('@timestamp, search_type, results_type, result_count, commodity_result_count, query')
  end

  it 'limits the empty-rate chart to search types with an empty-result rule' do
    query = widget_query(module_main_tf, 'Empty events, % of classic, interactive and internal completions, hourly')

    expect(query).to include('${local.defined_empty_search_types}')
    expect(query).to include('${local.zero_result_condition}')
    expect(query).not_to include('classification')
    expect(expand_tf_local(module_main_tf, 'defined_empty_search_types')).to eq(
      '(search_type = "classic" or search_type = "interactive" or search_type = "internal")',
    )
  end

  it 'uses numeric flag comparisons and explicit presence for unknown flags' do
    matched = widget_query(module_main_tf, 'Intercept checks by match result, hourly')
    rates = widget_query(module_main_tf, 'Guard checks per hour, all-check denominator')
    outcome = expand_tf_local(module_main_tf, 'guard_outcome_category')

    expect(expand_tf_local(module_main_tf, 'suspicious_one')).to eq('(suspicious = 1)')
    expect(expand_tf_local(module_main_tf, 'matched_zero')).to eq('(ispresent(matched) and matched = 0)')
    queries = module_main_tf.scan(/<<-EOT\n(.*?)\n\s+EOT/m).flatten.join
    expect(queries).not_to match(/=\s*true|=\s*false/)
    expect(rates).not_to include('coalesce(')
    expect(matched).to include('case(${local.matched_one}, "Matched", ${local.matched_zero}, "Not matched", "Unknown")')
    expect(rates).to include('sum(if(suspicious = 1, 1, 0)) as suspicious_events')
    expect(rates).to include('sum(if(duplicate = 1, 1, 0)) as duplicate_events')
    expect(rates).to include('${local.unknown_flag_condition}')
    expect(expand_tf_local(module_main_tf, 'unknown_flag_condition')).to include('not ispresent(suspicious)', 'ispresent(suspicious) and not (suspicious = 1 or suspicious = 0)')
    expect(outcome).to include(
      'reason = "guard_disabled"',
      '"Disabled"',
      '"Not suspicious"',
      '"Validator unavailable/unparseable, allowed"',
      '"Suspicious, allowed without fail-open marker"',
      '"Duplicate blocked"',
      '"Unknown/inconsistent"',
    )
    expect(outcome).not_to include('guard_disabled =')
  end

  it 'records intended guard categories, not engine semantics' do
    expression = expand_tf_local(module_main_tf, 'guard_outcome_category')
    records = {
      { suspicious: 0, duplicate: 0, allowed: 1, reason: 'guard_disabled' } => 'Disabled',
      { suspicious: 0, duplicate: 0, allowed: 1, reason: 'not_suspicious' } => 'Not suspicious',
      { suspicious: 1, duplicate: 0, allowed: 1, reason: 'validator_unparseable' } => 'Validator unavailable/unparseable, allowed',
      { suspicious: 1, duplicate: 0, allowed: 1, reason: 'distinct question' } => 'Suspicious, allowed without fail-open marker',
      { suspicious: 1, duplicate: 1, allowed: 0, reason: 'duplicate_question' } => 'Duplicate blocked',
      { suspicious: 1, duplicate: 0, allowed: 1 } => 'Unknown/inconsistent',
      { suspicious: 1, duplicate: 0, allowed: 0, reason: 'guard_disabled' } => 'Unknown/inconsistent',
      { duplicate: 0, allowed: 1, reason: 'not_suspicious' } => 'Unknown/inconsistent',
      { suspicious: 2, duplicate: 0, allowed: 1, reason: 'not_suspicious' } => 'Unknown/inconsistent',
    }

    expect(records.values.uniq.size).to eq(6)
    records.each do |record, expected|
      expect(evaluate_guard_case(expression, record)).to eq(expected)
    end
    unknown = expand_tf_local(module_main_tf, 'unknown_flag_condition')
    samples = [
      { suspicious: 1, duplicate: 0, allowed: 1 },
      { duplicate: 0, allowed: 1 },
      { suspicious: 2, duplicate: 0, allowed: 1 },
    ]
    expect(samples.count { |record| evaluate_guard_condition(unknown, record) }).to eq(2)
  end

  it 'keeps parsed guard signals and hides the parse helper' do
    signals = widget_query(module_main_tf, 'Suspicious guard checks by signal, overlapping categories')
    decisions = widget_query(module_main_tf, 'Latest 30 guard decisions')

    expect(signals).to include('and suspicious = 1')
    expect(signals).to include('fields jsonParse(@message) as guard')
    expect(signals).to include('unnest guard.signals into signal')
    expect(decisions).to include('fields jsonParse(@message) as guard')
    expect(decisions).to include('jsonStringify(guard.signals) as signal_list')
    expect(decisions).to include('display @timestamp, request_id, attempt_number, suspicious, duplicate, allowed, signal_list, reason, reason_truncated, duplicate_of_question, duplicate_of_answer')
    expect(decisions).not_to include('display @timestamp, request_id, attempt_number, suspicious, duplicate, allowed, guard')
  end

  it 'labels field presence separately from validated telemetry' do
    coverage = widget_query(module_main_tf, 'Field presence by search type and free-text cohort, hourly')

    expect_one_title('Field presence by search type and free-text cohort, hourly')
    expect(coverage).to include('coalesce(case(not ispresent(query), "Missing query", ${local.non_numeric_query_condition}, "in free-text cohort", "outside free-text cohort"), "Unknown")')
    expect(coverage).to include('${local.non_numeric_query_condition}')
    expect(widget_query(module_main_tf, 'Classic free-text non-exact empty commodity %, hourly')).not_to include('Missing query')
    expect(widget_query(module_main_tf, 'Guided free-text no-results %, hourly')).not_to include('Missing query')
    expect(widget_query(module_main_tf, 'Empty events, % of classic, interactive and internal completions, hourly')).not_to include('Missing query')
    expect(coverage).to include('events_with_result_count')
    expect(coverage).to include('events_with_commodity_count')
    expect(coverage).to include('events_with_complete_classic_level_breakdown')
    expect(coverage).to include('by search_type, free_text_cohort, bin(1h)')
    expect(coverage).not_to include('validated')
  end
end

# Intent model only. This does not reproduce Logs Insights nulls, short-circuiting, or comparison behaviour.
class CwliExpression
  def initialize(source, record)
    @record = record.transform_keys(&:to_s)
    @tokens = source.scan(/"(?:\\.|[^"\\])*"|-?\d+|ispresent|[A-Za-z_][A-Za-z0-9_]*|!=|[=(),]/)
    @index = 0
  end

  def parse_case
    expect('case')
    expect('(')
    arguments = [parse_or]
    arguments << parse_or while accept?(',')
    expect(')')
    arguments.each_slice(2) do |condition, value|
      return value if value && condition
      return condition unless value
    end
  end

  def parse_or
    left = parse_and
    while accept?('or')
      right = parse_and
      left = left || right # rubocop:disable Style/SelfAssignment
    end
    left
  end

private

  def parse_and
    left = parse_not
    while accept?('and')
      right = parse_not
      left = left && right # rubocop:disable Style/SelfAssignment
    end
    left
  end

  def parse_not
    return !parse_not if accept?('not')

    parse_comparison
  end

  def parse_comparison
    left = parse_primary
    if accept?('=')
      left == parse_primary
    elsif accept?('!=')
      left != parse_primary
    else
      left
    end
  end

  def parse_primary
    token = take
    return Integer(token) if token.match?(/\A-?\d+\z/)
    return token.delete_prefix('"').delete_suffix('"') if token.start_with?('"')

    if token == 'ispresent'
      expect('(')
      name = take
      expect(')')
      return @record.key?(name) && !@record[name].nil?
    end
    return parse_or.tap { expect(')') } if token == '('

    @record[token]
  end

  def accept?(token)
    return false unless @tokens[@index] == token

    @index += 1
    true
  end

  def expect(token)
    raise "expected #{token}, got #{@tokens[@index].inspect}" unless accept?(token)
  end

  def take
    token = @tokens[@index]
    raise 'unexpected end of expression' unless token

    @index += 1
    token
  end
end
