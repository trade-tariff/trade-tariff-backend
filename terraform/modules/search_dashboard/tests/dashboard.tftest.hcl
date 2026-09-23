mock_provider "aws" {}

variables {
  environment    = "test"
  region         = "eu-west-2"
  log_group_name = "platform-logs-test"
}

run "experiment_activity" {
  command = plan

  assert {
    condition = (
      length(output.queries) == 1 &&
      output.queries["Active browser sessions by experiment"].query_language == "CWLI" &&
      strcontains(output.queries["Active browser sessions by experiment"].query_string, "SOURCE 'platform-logs-test'") &&
      strcontains(output.queries["Active browser sessions by experiment"].query_string, "count_distinct(browser_session_id) as estimated_active_browser_sessions by experiment")
    )
    error_message = "The sole Overview log query must count distinct sessions per experiment and remain in the query validator."
  }

  assert {
    condition = alltrue([for w in local.dashboard_body.widgets :
      w.properties.view == "bar" && w.properties.region == "eu-west-2" &&
      strcontains(w.properties.query, "event = \"guided_search.journey\" and schema_version = 1 and outcome = \"page_visible\"") &&
      strcontains(w.properties.query, "browser_session_id like /^v1:[0-9a-f]{64}$/") &&
      strcontains(w.properties.query, "experiment like /\\S/") &&
      strcontains(w.properties.query, "limit 30")
      if w.type == "log"
    ])
    error_message = "Activity needs visible-page events with valid identity and labels; show a bounded bar chart, not mutually exclusive pie slices."
  }

  assert {
    condition = alltrue(flatten([for i, a in local.dashboard_body.widgets : [for j, b in local.dashboard_body.widgets :
      i == j || a.x + a.width <= b.x || b.x + b.width <= a.x || a.y + a.height <= b.y || b.y + b.height <= a.y
    ]]))
    error_message = "The experiment activity section must not overlap existing charts."
  }
}
