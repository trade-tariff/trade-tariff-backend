mock_provider "aws" {}

variables {
  environment    = "test"
  region         = "eu-west-2"
  log_group_name = "platform-logs-test"
}

run "reuse_existing_counts" {
  command = plan

  assert {
    condition = (
      local.dashboard_body.periodOverride == "inherit" &&
      length([for w in local.dashboard_body.widgets : w if w.type == "metric"]) == 2 &&
      alltrue([for w in local.dashboard_body.widgets :
        w.properties.stat == "Sum" && w.properties.region == "eu-west-2"
        if w.type == "metric"
      ])
    )
    error_message = "Only equivalent count widgets should use metrics, with their own periods and region."
  }

  assert {
    condition = length([for w in local.dashboard_body.widgets : w if try(w.properties.title, "") == "Completed searches and selections per hour, UK + XI"]) == 1 && alltrue([for w in local.dashboard_body.widgets :
      w.type == "metric" && w.properties.view == "timeSeries" && w.properties.period == 3600 &&
      w.properties.yAxis.left.min == 0 &&
      length(w.properties.metrics) == 6 &&
      alltrue([for i, service in ["uk", "xi"] :
        w.properties.metrics[i] == ["TradeTariff/Search", "SearchEvents", "Environment", "test", "Service", service, "Outcome", "completed", { id = "completed_${service}", visible = false }] &&
        w.properties.metrics[i + 2] == ["TradeTariff/Search", "ResultSelections", "Environment", "test", "Service", service, { id = "selected_${service}", visible = false }]
      ]) &&
      w.properties.metrics[4][0].label == "search_completed" &&
      w.properties.metrics[4][0].expression == "IF(completed_uk + completed_xi > 0, completed_uk + completed_xi)" &&
      w.properties.metrics[5][0].label == "result_selected" &&
      w.properties.metrics[5][0].expression == "IF(selected_uk + selected_xi > 0, selected_uk + selected_xi)"
      if try(w.properties.title, "") == "Completed searches and selections per hour, UK + XI"
    ])
    error_message = "Keep hourly event totals pooled across UK/XI, exclude failures and use only one dimension rollup. Do not invent zeroes in empty periods."
  }

  assert {
    condition = length([for w in local.dashboard_body.widgets : w if try(w.properties.title, "") == "Recorded empty events by search type, UK + XI"]) == 1 && alltrue([for w in local.dashboard_body.widgets :
      w.type == "metric" && w.properties.view == "bar" && w.properties.setPeriodToTimeRange &&
      w.properties.yAxis.left.min == 0 &&
      length(w.properties.metrics) == 9 &&
      alltrue([for i, search_type in ["classic", "interactive", "internal"] :
        w.properties.metrics[i] == ["TradeTariff/Search", "EmptyResults", "Environment", "test", "Service", "uk", "SearchType", search_type, { id = "empty_${search_type}_uk", visible = false }] &&
        w.properties.metrics[i + 3] == ["TradeTariff/Search", "EmptyResults", "Environment", "test", "Service", "xi", "SearchType", search_type, { id = "empty_${search_type}_xi", visible = false }] &&
        w.properties.metrics[i + 6][0].label == search_type &&
        w.properties.metrics[i + 6][0].expression == "IF(empty_${search_type}_uk + empty_${search_type}_xi > 0, empty_${search_type}_uk + empty_${search_type}_xi)"
      ])
      if try(w.properties.title, "") == "Recorded empty events by search type, UK + XI"
    ])
    error_message = "Keep whole-window totals by search type, not the latest period, and preserve empty populations as gaps."
  }

  assert {
    condition = alltrue([for w in local.dashboard_body.widgets :
      w.type == "log" && strcontains(w.properties.query, "SOURCE 'platform-logs-test'")
      if !contains(["", "Completed searches and selections per hour, UK + XI", "Recorded empty events by search type, UK + XI"], try(w.properties.title, ""))
    ])
    error_message = "Leave cohort rates, pooled medians, raw labels and request details on logs."
  }

  assert {
    condition = (
      strcontains(local.dashboard_body.widgets[0].properties.markdown, "History starts at metric collection") &&
      strcontains(local.dashboard_body.widgets[0].properties.markdown, "gaps are not zero") &&
      local.dashboard_body.widgets[0].height == 4 &&
      local.dashboard_body.widgets[0].width == 24
    )
    error_message = "Explain the metric history cutoff and missing data on a four-row header."
  }
}

run "presentation_contract" {
  command = plan

  assert {
    condition = (
      length(local.dashboard_body.widgets) == 29 &&
      length([for w in local.dashboard_body.widgets : w if w.type == "log"]) == 26 &&
      length([for w in local.dashboard_body.widgets : w if w.type == "text"]) == 1
    )
    error_message = "The coverage table is the only additional log scan: 26 log widgets."
  }

  assert {
    condition = alltrue(flatten([
      for i, left in local.dashboard_body.widgets : [
        for j, right in local.dashboard_body.widgets :
        i == j || left.x + left.width <= right.x || right.x + right.width <= left.x || left.y + left.height <= right.y || right.y + right.height <= left.y
      ]
      ])) && alltrue([
      for widget in local.dashboard_body.widgets :
      widget.x >= 0 && widget.y >= 0 && widget.x + widget.width <= 24 && (widget.width == 12 || widget.width == 24)
    ])
    error_message = "Use a non-overlapping 12-column or full-width layout."
  }

  assert {
    condition = alltrue([
      for title in [
        "Interactive completed events by response type",
        "Completed events by results type, all search types",
        "Hourly mean and median results per completed event",
        "Classic completed events by outcome",
        "Classic empty events: no results versus other hits only",
        "Top 30 empty queries, including code lookups",
        "Latest 30 empty events",
        "Matched intercept configurations",
        "Top 30 intercept term/configuration combinations",
        "Guided round number at request completion",
        "Submitted answer-history entries at request completion",
        "Guard checks by mutually exclusive outcome",
        "Guard checks per hour, all-check denominator",
        "Suspicious guard checks by signal, overlapping categories",
        "Latest 30 guard decisions",
        "Latest 30 matched intercept checks",
        "Field presence by search type and free-text cohort, hourly",
        "Intercept checks by match result, hourly",
        "Classic empty events, % of all completions, hourly",
        "Classic free-text non-exact empty commodity %, hourly",
        "Guided free-text no-results %, hourly",
        "Empty events, % of classic, interactive and internal completions, hourly",
      ] : length([for w in local.dashboard_body.widgets : w if try(w.properties.title, "") == title]) == 1
    ])
    error_message = "Each renamed widget must exist exactly once."
  }

  assert {
    condition = alltrue([
      for title in [
        "Classic empty events, % of all completions, hourly",
        "Classic free-text non-exact empty commodity %, hourly",
        "Guided free-text no-results %, hourly",
        "Empty events, % of classic, interactive and internal completions, hourly",
        ] : length([for w in local.dashboard_body.widgets : w if try(w.properties.title, "") == title]) == 1 && alltrue([
          for widget in [for w in local.dashboard_body.widgets : w if try(w.properties.title, "") == title] :
          widget.type == "log" && widget.properties.view == "timeSeries" && widget.properties.yAxis.left.min == 0 && widget.properties.yAxis.left.max == 100
      ])
    ])
    error_message = "Each percentage chart must exist as a time series with a 0-100 axis."
  }

  assert {
    condition = (
      length([for w in local.dashboard_body.widgets : w if try(w.properties.title, "") == "Intercept checks by match result, hourly"]) == 1 &&
      alltrue([
        for widget in [for w in local.dashboard_body.widgets : w if try(w.properties.title, "") == "Intercept checks by match result, hourly"] :
        widget.properties.view == "timeSeries" &&
        strcontains(widget.properties.query, "\"Not matched\"") &&
        strcontains(widget.properties.query, "ispresent(matched) and matched = 0") &&
        strcontains(widget.properties.query, "matched = 1") &&
        strcontains(widget.properties.query, "\"Unknown\"") &&
        !strcontains(widget.properties.query, "= true") &&
        !strcontains(widget.properties.query, "= false")
      ]) &&
      length([for w in local.dashboard_body.widgets : w if try(w.properties.title, "") == "Suspicious guard checks by signal, overlapping categories"]) == 1 &&
      alltrue([
        for widget in [for w in local.dashboard_body.widgets : w if try(w.properties.title, "") == "Suspicious guard checks by signal, overlapping categories"] :
        widget.properties.view == "table" &&
        strcontains(widget.properties.query, "suspicious = 1") &&
        !strcontains(widget.properties.query, "= true") &&
        strcontains(widget.properties.query, "jsonParse(@message)") &&
        strcontains(widget.properties.query, "unnest guard.signals into signal")
      ]) &&
      length([for w in local.dashboard_body.widgets : w if try(w.properties.title, "") == "Latest 30 guard decisions"]) == 1 &&
      alltrue([
        for widget in [for w in local.dashboard_body.widgets : w if try(w.properties.title, "") == "Latest 30 guard decisions"] :
        widget.properties.view == "table" &&
        strcontains(widget.properties.query, "jsonStringify(guard.signals) as signal_list") &&
        strcontains(widget.properties.query, "display @timestamp, request_id, attempt_number, suspicious, duplicate, allowed, signal_list, reason, reason_truncated, duplicate_of_question, duplicate_of_answer") &&
        !strcontains(widget.properties.query, "display @timestamp, request_id, attempt_number, suspicious, duplicate, allowed, guard")
      ]) &&
      length([for w in local.dashboard_body.widgets : w if try(w.properties.title, "") == "Guard checks per hour, all-check denominator"]) == 1 &&
      alltrue([
        for widget in [for w in local.dashboard_body.widgets : w if try(w.properties.title, "") == "Guard checks per hour, all-check denominator"] :
        strcontains(widget.properties.query, "sum(if(suspicious = 1, 1, 0))") &&
        strcontains(widget.properties.query, "not ispresent(suspicious)") &&
        strcontains(widget.properties.query, "ispresent(suspicious) and not (suspicious = 1 or suspicious = 0)") &&
        !strcontains(widget.properties.query, "coalesce(")
      ]) &&
      length([for w in local.dashboard_body.widgets : w if try(w.properties.title, "") == "Field presence by search type and free-text cohort, hourly"]) == 1 &&
      alltrue([
        for widget in [for w in local.dashboard_body.widgets : w if try(w.properties.title, "") == "Field presence by search type and free-text cohort, hourly"] :
        strcontains(widget.properties.query, "not ispresent(query), \"Missing query\"") &&
        strcontains(widget.properties.query, "query not like /^[0-9 .-]+$/") &&
        strcontains(widget.properties.query, "\"in free-text cohort\"") &&
        strcontains(widget.properties.query, "\"outside free-text cohort\"") &&
        strcontains(widget.properties.query, "\"Unknown\"")
      ])
    )
    error_message = "Assert the intercept, signal, guard-decision and unknown-flag widgets before checking their properties."
  }
}
