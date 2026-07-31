# frozen_string_literal: true

RSpec.describe 'search experiment dashboard Terraform' do
  let(:dashboards_tf) { Rails.root.join('terraform/dashboards.tf').read }
  let(:module_main_tf) { Rails.root.join('terraform/modules/search_experiment_dashboard/main.tf').read }
  let(:operations_dashboard_tf) { Rails.root.join('terraform/modules/search_operations_dashboard/main.tf').read }
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
    expect(module_main_tf).to include('E2E Latency in seconds (p50/p90/p99)')
    expect(module_main_tf).to include('Search Response Types')
    expect(module_main_tf).to include('Questions per Search')
    expect(module_main_tf).to include('Top Search Terms')
    expect(module_main_tf).to include('Total AI Cost by Operation')
    expect(module_main_tf).to include('Recent UAT Events')
  end

  it 'explains how to interpret and investigate the production UAT cohort' do
    expect(module_main_tf).to include('Production UAT')
    expect(module_main_tf).to include('Requests and estimated distinct guided-search browser sessions are reported separately.')
    expect(module_main_tf).to include('One browser session can contain multiple requests.')
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
    expect(module_main_tf).to include('sum(input_tokens) as input_token_total')
    expect(module_main_tf).to include('sum(output_tokens) as output_token_total')
    expect(module_main_tf).to include('Unknown Pricing Events')
    expect(module_main_tf).to include('not pricing_known or not ispresent(total_cost_usd)')
    expect(module_main_tf).not_to include('pricing_known = true')
    expect(module_main_tf).not_to include('pricing_known = false')
    expect(module_main_tf).not_to include('AI Tokens and Cost')
  end

  it 'shows token totals as one readable table' do
    token_widget = widget_definition('AI Token Totals by Operation')

    expect(token_widget).not_to include('view   = "bar"')
    expect(token_widget).to include(
      'stats sum(input_tokens) as input_token_total, sum(output_tokens) as output_token_total, sum(total_tokens) as token_total by ai_operation, model',
    )
    expect(token_widget).to include('| sort token_total desc')
  end

  it 'summarises the UAT period and exposes the behaviour needed for diagnosis' do
    uat_period_totals_query = widget_query('UAT Period Totals')

    expect(module_main_tf).to include('UAT Period Totals')
    expect(uat_period_totals_query).to include('sum(if(event = "search_completed", 1, 0)) as completed_requests')
    expect(uat_period_totals_query).to include('sum(if(event = "search_failed", 1, 0)) as hard_failures')
    expect(uat_period_totals_query).to include('sum(if(event = "search_completed" and final_result_type = "error", 1, 0)) as error_outcomes')
    expect(uat_period_totals_query).to include('commodity_result_count = 0')
    expect(uat_period_totals_query).to include('zero_result_requests')
    expect(uat_period_totals_query).to include('sum(if(event = "guided_search.journey" and outcome = "result_selected", 1, 0)) as selections')
    expect(module_main_tf).to include('Questions and Answer Options')
    expect(module_main_tf).to include('event in ["question_returned", "answer_returned"]')
    expect(module_main_tf).to include('event_payload.details.questions[0].question as question')
    expect(module_main_tf).to include('details.answers.0.commodity_code as top_commodity_code')
    expect(module_main_tf).to include('details.answers.0.confidence as top_confidence')
    expect(module_main_tf).to include('Selected Results')
    expect(module_main_tf).to include('goods_nomenclature_item_id')
    expect(module_main_tf).to include('Top Zero-Result Terms')
  end

  it 'reports estimated browser sessions from valid v1 guided-search events' do
    uat_period_totals_query = widget_query('UAT Period Totals')

    expect(uat_period_totals_query).to include('${local.experiment_filter}')
    expect(uat_period_totals_query).to include('service = "search" and event in ["search_completed", "search_failed"]')
    expect(uat_period_totals_query).to include(
      'case(event = "guided_search.journey" and schema_version = 1 and browser_session_id like /^v1:[0-9a-f]{64}$/, browser_session_id) as guided_search_browser_session_id',
    )
    expect(uat_period_totals_query).to include('or ispresent(guided_search_browser_session_id)')
    expect(uat_period_totals_query).to include(
      'count_distinct(guided_search_browser_session_id) as estimated_browser_sessions',
    )
  end

  it 'makes estimated browser sessions directly visible without exposing identifiers' do
    unique_sessions_query = widget_query('Estimated Unique Browser Sessions')

    expect(module_main_tf).to match(
      /title\s+= "Estimated Unique Browser Sessions"\n\s+region = var\.region\n\s+query\s+= <<-EOT/,
    )
    expect(unique_sessions_query).to include('${local.experiment_filter}')
    expect(unique_sessions_query).to include(
      'event = "guided_search.journey" and schema_version = 1',
    )
    expect(unique_sessions_query).to include('browser_session_id like /^v1:[0-9a-f]{64}$/')
    expect(unique_sessions_query).to include(
      'count_distinct(browser_session_id) as estimated_browser_sessions',
    )
    expect(unique_sessions_query).not_to include('| fields browser_session_id')
  end

  it 'breaks browser-confirmed page destinations down by views, requests, and sessions' do
    destinations_query = widget_query('Guided Search Page Destinations')

    expect(destinations_query).to include('outcome = "page_visible"')
    expect(destinations_query).to include('browser_session_id like /^v1:[0-9a-f]{64}$/')
    expect(destinations_query).to include(
      'stats count(*) as page_views, count_distinct(request_id) as distinct_requests,',
    )
    expect(destinations_query).to include(
      'count_distinct(browser_session_id) as estimated_browser_sessions by destination',
    )
  end

  it 'combines frontend journey errors and backend search failures by outcome' do
    errors_query = widget_query('Guided Search Errors and Fallbacks')

    expect(errors_query).to include(
      'event = "guided_search.journey" and schema_version = 1 and outcome in ["input_error", "backend_error", "no_results", "unknown_results", "blocking_guidance"]',
    )
    expect(errors_query).to include('service = "search" and event = "search_failed"')
    expect(errors_query).to include(
      'service = "search" and event = "search_completed" and final_result_type = "error"',
    )
    expect(errors_query).to include(
      'stats count(*) as events, count_distinct(request_id) as distinct_requests by error_or_fallback',
    )
  end

  it 'reports dont-know usage and rate against displayed questions' do
    dont_know_query = widget_query("I Don't Know Usage")

    expect(dont_know_query).to include('outcome in ["page_visible", "dont_know"]')
    expect(dont_know_query).to include(
      'sum(if(outcome = "dont_know", 1, 0)) as dont_know_uses',
    )
    expect(dont_know_query).to include(
      'count_distinct(dont_know_request_id) as requests_using_dont_know',
    )
    expect(dont_know_query).to include(
      'count_distinct(question_request_id) as requests_shown_questions',
    )
    expect(dont_know_query).to include(
      'case(outcome = "dont_know", request_id) as dont_know_request_id',
    )
    expect(dont_know_query).to include(
      'case(outcome = "dont_know" or (outcome = "page_visible" and destination = "question"), request_id) as question_request_id',
    )
    expect(dont_know_query).to include(
      'requests_using_dont_know * 100 / requests_shown_questions as request_usage_rate_percent',
    )
    expect(dont_know_query).to include(
      'filter requests_shown_questions > 0',
    )
    expect(dont_know_query).to include(
      'display dont_know_uses, requests_using_dont_know, requests_shown_questions, request_usage_rate_percent',
    )
  end

  it 'shows client journey timings in explicitly labelled seconds' do
    navigation_query = widget_query('Client Navigation Time in seconds by Destination (p50/p90/p99)')
    question_query = widget_query('Question Response Time in seconds (p50/p90/p99)')

    expect(navigation_query).to include('outcome = "page_visible"')
    expect(navigation_query).to include(
      'pct(client_navigation_ms / 1000, 50) as p50_seconds',
    )
    expect(navigation_query).to include('by destination')
    expect(question_query).to include('ispresent(client_elapsed_ms)')
    expect(question_query).to include(
      'pct(client_elapsed_ms / 1000, 50) as p50_seconds',
    )
    expect(question_query).not_to include('by question_count')
  end

  it 'shows the answer options returned with each question' do
    questions_query = widget_query('Questions and Answer Options')

    expect(questions_query).to include('jsonParse(@message) as event_payload')
    expect(questions_query).to include('event_payload.details.questions[0].question as question')
    expect(questions_query).to include(
      'jsonStringify(event_payload.details.questions[0].options) as answer_options',
    )
  end

  it 'counts started searches once per request' do
    top_search_terms_query = widget_query('Top Search Terms')

    expect(top_search_terms_query).to include(
      'stats count_distinct(request_id) as searches by query, search_type',
    )
    expect(top_search_terms_query).not_to include('stats count(*) as searches')
  end

  it 'lists each recent started search once' do
    recent_searches_query = operations_widget_query('Recent Searches')

    expect(recent_searches_query).to include(
      'stats latest(@timestamp) as latest_timestamp, latest(query) as query,',
    )
    expect(recent_searches_query).to include('by request_id')
    expect(recent_searches_query).to include(
      'display latest_timestamp, query, request_source, search_type, request_id',
    )
  end

  it 'uses frontend journey events for guided-search result selections' do
    selected_results_query = widget_query('Selected Results')

    expect(selected_results_query).to include('${local.experiment_filter}')
    expect(selected_results_query).to include(
      'event = "guided_search.journey" and schema_version = 1 and outcome = "result_selected"',
    )
    expect(selected_results_query).to include('browser_session_id like /^v1:[0-9a-f]{64}$/')
    expect(selected_results_query).to include('stats count(*) as selections by goods_nomenclature_item_id, confidence')
    expect(selected_results_query).not_to include('${local.search_filter}')
  end

  it 'shows journey diagnostics without exposing browser session identifiers' do
    recent_uat_events_query = widget_query('Recent UAT Events')

    expect(recent_uat_events_query).to include(
      'outcome, destination, result_rank, confidence, used_dont_know, client_elapsed_ms, client_navigation_ms',
    )
    expect(recent_uat_events_query).not_to include('browser_session_id')
  end

  it 'shows overall provider latency percentiles as a comparable time series' do
    expect(module_main_tf).to include('AI API Latency in seconds (p50/p90/p99)')
    expect(module_main_tf).to include('pct(duration_ms / 1000, 50) as p50_seconds')
    expect(widget_query('AI API Latency in seconds (p50/p90/p99)')).to include('by bin(1h)')
    expect(widget_query('AI API Latency in seconds (p50/p90/p99)')).not_to include('by operation, bin(1h)')
  end

  it 'renders latency percentiles together instead of splitting them into dimension panes' do
    expect(widget_query('E2E Latency in seconds (p50/p90/p99)')).to include('by bin(1h)')
    expect(widget_query('E2E Latency in seconds (p50/p90/p99)')).not_to include('by search_type, bin(1h)')
  end

  it 'uses renderable hourly request volume series' do
    expect(module_main_tf).to include('sum(if(event = "search_completed", 1, 0)) as completed_requests')
    expect(module_main_tf).to include('sum(if(event = "search_failed", 1, 0)) as failed_requests')
    expect(module_main_tf).to include('as failed_requests by search_type, bin(1h)')
    expect(module_main_tf).not_to include('stats count(*) as searches by event, search_type, bin(1h)')
  end

  it 'gives detailed diagnostics enough horizontal space' do
    expect(module_main_tf).to match(/width\s+= 8\n\s+height\s+= 6\n\s+properties = \{\n\s+title\s+= "UAT Period Totals"/)
    expect(module_main_tf).to match(/width\s+= 12\n\s+height\s+= 6\n\s+properties = \{\n\s+title\s+= "Total AI Cost by Operation"/)
    expect(module_main_tf).to match(/width\s+= 12\n\s+height\s+= 6\n\s+properties = \{\n\s+title\s+= "AI Token Totals by Operation"/)
    expect(module_main_tf).to match(/width\s+= 16\n\s+height\s+= 6\n\s+properties = \{\n\s+title\s+= "AI API Latency in seconds \(p50\/p90\/p99\)"/)
    expect(module_main_tf).to match(/width\s+= 24\n\s+height\s+= 6\n\s+properties = \{\n\s+title\s+= "Questions and Answer Options"/)
    expect(module_main_tf).to include('| fields event_payload.details.questions[0].question as question,')
  end

  it 'uses plain-language labels for every search response type' do
    search_response_types_query = widget_query('Search Response Types')

    expect(search_response_types_query).to include(
      'case(final_result_type = "answers", "suggested results", final_result_type = "questions", "questions", final_result_type = "error", "errors", result_count = 0, "no results", "results without questions") as search_response_type',
    )
    expect(search_response_types_query).to include(
      'stats count(*) as completed_searches by search_response_type',
    )
    expect(module_main_tf).not_to include('Final Result Types')
  end

  it 'is discoverable from the search overview dashboard' do
    expect(search_dashboard_tf).to include('Search Experiments')
    expect(search_dashboard_tf).to include('SearchExperiment-${var.environment}')
  end

  def widget_query(title)
    module_main_tf.match(/title\s+= "#{Regexp.escape(title)}".*?query\s+= <<-EOT\n(.*?)\n\s+EOT/m).then do |match|
      expect(match).to be_present
      match[1]
    end
  end

  def widget_definition(title)
    module_main_tf.match(/properties = \{\n\s+title\s+= "#{Regexp.escape(title)}".*?\n\s+EOT/m).then do |match|
      expect(match).to be_present
      match[0]
    end
  end

  def operations_widget_query(title)
    operations_dashboard_tf.match(/title\s+= "#{Regexp.escape(title)}".*?query\s+= <<-EOT\n(.*?)\n\s+EOT/m).then do |match|
      expect(match).to be_present
      match[1]
    end
  end
end
