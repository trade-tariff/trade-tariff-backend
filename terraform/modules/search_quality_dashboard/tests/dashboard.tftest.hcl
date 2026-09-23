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
    condition = alltrue([for w in local.dashboard_body.widgets :
      w.type == "metric" && w.properties.view == "timeSeries" && w.properties.period == 3600 &&
      length(w.properties.metrics) == 6 &&
      alltrue([for i, service in ["uk", "xi"] :
        w.properties.metrics[i] == ["TradeTariff/Search", "SearchEvents", "Environment", "test", "Service", service, "Outcome", "completed", { id = "completed_${service}", visible = false }] &&
        w.properties.metrics[i + 2] == ["TradeTariff/Search", "ResultSelections", "Environment", "test", "Service", service, { id = "selected_${service}", visible = false }]
      ]) &&
      w.properties.metrics[4][0].label == "search_completed" &&
      w.properties.metrics[4][0].expression == "IF(completed_uk + completed_xi > 0, completed_uk + completed_xi)" &&
      w.properties.metrics[5][0].label == "result_selected" &&
      w.properties.metrics[5][0].expression == "IF(selected_uk + selected_xi > 0, selected_uk + selected_xi)"
      if try(w.properties.title, "") == "Searches vs Selections"
    ])
    error_message = "Keep hourly event totals pooled across UK/XI, exclude failures and use only one dimension rollup. Do not invent zeroes in empty periods."
  }

  assert {
    condition = alltrue([for w in local.dashboard_body.widgets :
      w.type == "metric" && w.properties.view == "pie" && w.properties.setPeriodToTimeRange &&
      length(w.properties.metrics) == 9 &&
      alltrue([for i, search_type in ["classic", "interactive", "internal"] :
        w.properties.metrics[i] == ["TradeTariff/Search", "EmptyResults", "Environment", "test", "Service", "uk", "SearchType", search_type, { id = "empty_${search_type}_uk", visible = false }] &&
        w.properties.metrics[i + 3] == ["TradeTariff/Search", "EmptyResults", "Environment", "test", "Service", "xi", "SearchType", search_type, { id = "empty_${search_type}_xi", visible = false }] &&
        w.properties.metrics[i + 6][0].label == search_type &&
        w.properties.metrics[i + 6][0].expression == "IF(empty_${search_type}_uk + empty_${search_type}_xi > 0, empty_${search_type}_uk + empty_${search_type}_xi)"
      ])
      if try(w.properties.title, "") == "Empty Commodity / Empty Results by Search Type"
    ])
    error_message = "Keep whole-window totals by search type, not the latest period, and preserve empty populations as gaps."
  }

  assert {
    condition = alltrue([for w in local.dashboard_body.widgets :
      w.type == "log" && strcontains(w.properties.query, "SOURCE 'platform-logs-test'")
      if !contains(["", "Searches vs Selections", "Empty Commodity / Empty Results by Search Type"], try(w.properties.title, ""))
    ])
    error_message = "Leave cohort rates, pooled medians, raw labels and request details on logs."
  }

  assert {
    condition = (
      strcontains(local.dashboard_body.widgets[0].properties.markdown, "History starts at metric collection") &&
      strcontains(local.dashboard_body.widgets[0].properties.markdown, "gaps are not zero")
    )
    error_message = "Explain the metric history cutoff and missing data on the dashboard."
  }
}
