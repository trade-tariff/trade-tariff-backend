mock_provider "aws" {}

variables {
  environment    = "test"
  region         = "eu-west-2"
  log_group_name = "platform-logs-test"
}

run "operations_and_diagnostics" {
  command = plan

  assert {
    condition = (
      aws_cloudwatch_dashboard.search_operations.dashboard_name == "SearchOperations-test" &&
      aws_cloudwatch_dashboard.search_diagnostics.dashboard_name == "SearchOperations-test-Diagnostics" &&
      length(local.dashboard_body.widgets) == 24 &&
      local.dashboard_body.periodOverride == "inherit" &&
      local.dashboard_body.start == "-PT3H" &&
      alltrue([for w in local.dashboard_body.widgets : contains(["text", "metric"], w.type)])
    )
    error_message = "Operations must retain its name and load only metrics; diagnostics has its own dashboard."
  }

  assert {
    condition = alltrue([
      for w in local.dashboard_body.widgets :
      w.properties.region == "eu-west-2" && w.properties.period == 300 && w.properties.yAxis.left.min == 0
      if w.type == "metric"
    ])
    error_message = "Operations metrics must use the selected region, five-minute periods and labelled axes."
  }

  assert {
    condition = alltrue([
      for w in local.dashboard_body.widgets :
      length(w.properties.metrics) == 6 &&
      alltrue([for m in w.properties.metrics : contains(["p50", "p90", "p99"], m[6].stat)]) &&
      length([for m in w.properties.metrics : m if m[5] == "uk"]) == 3 &&
      length([for m in w.properties.metrics : m if m[5] == "xi"]) == 3
      if try(w.properties.title, "") == "Completed server request latency (seconds, p50/p90/p99)"
    ])
    error_message = "Overall percentiles must remain separate for UK and XI without averaging percentiles."
  }

  assert {
    condition = (
      strcontains(aws_cloudwatch_dashboard.search_operations.dashboard_body, "100 * checks_uk") &&
      strcontains(aws_cloudwatch_dashboard.search_operations.dashboard_body, "DuplicateValidatorFailOpen") &&
      !strcontains(aws_cloudwatch_dashboard.search_operations.dashboard_body, "FILL(") &&
      !strcontains(aws_cloudwatch_dashboard.search_operations.dashboard_body, "SUM(SEARCH")
    )
    error_message = "The fail-open rate must use observed checks without filling gaps or summing metric rollups."
  }

  assert {
    condition = (
      alltrue([for m in local.request_volume : m[1] == "GuidedSearchErrors" && m[6].stat == "SampleCount"]) &&
      alltrue([for m in slice(local.request_error_percentage, 0, 2) : m[1] == "GuidedSearchErrors" && m[6].stat == "Average"]) &&
      alltrue([for w in local.dashboard_body.widgets :
        w.properties.setPeriodToTimeRange
        if contains(["singleValue", "bar"], try(w.properties.view, ""))
      ]) &&
      alltrue([for w in local.dashboard_body.widgets :
        w.properties.yAxis.left.max == 100
        if try(w.properties.yAxis.left.label, "") == "Percent"
      ])
    )
    error_message = "Error percentages and request counts need the same sample population, full-window summaries and percentage axes."
  }

  assert {
    condition = (
      alltrue([for w in local.dashboard_body.widgets :
        alltrue([for m in w.properties.metrics : m[1] == "GuidedSearchDuration"])
        if try(w.properties.title, "") == "Completed server request latency (seconds, p50/p90/p99)"
      ]) &&
      length([for w in local.dashboard_body.widgets : w if w.type == "text"]) == 4 &&
      alltrue([for w in local.dashboard_body.widgets :
        length(w.properties.metrics) == 4 &&
        alltrue([for m in w.properties.metrics : m[6] == "Operation" && contains(["search_query_expansion", "interactive_search", "interactive_search_final_answer"], m[7]) && contains(["p50", "p90"], m[8].stat)])
        if w.y == 22
      ]) &&
      alltrue([for w in local.dashboard_body.widgets :
        alltrue([for m in w.properties.metrics : m[1] == "DuplicateValidatorFailOpen" && m[6].stat == "SampleCount"])
        if try(w.properties.title, "") == "Validator-eligible checks per 5 minutes"
      ])
    )
    error_message = "Separate request health from dependency diagnostics, isolate latency operations and show the validator denominator."
  }

  assert {
    condition = alltrue([for w in local.dashboard_body.widgets :
      length(w.properties.metrics) == (w.properties.title == "Retrieval latency (seconds, p50/p90)" ? 16 : 8) &&
      length(distinct([for m in w.properties.metrics : m[8].label])) == length(w.properties.metrics) &&
      alltrue([for m in w.properties.metrics :
        contains(local.services, m[5]) && contains(["p50", "p90"], m[8].stat) &&
        m[8].label == "${upper(m[5])} ${m[6] == "Leg" ? m[7] : local.operations[m[7]]} ${m[8].stat}"
      ])
      if contains(["Retrieval latency (seconds, p50/p90)", "Duplicate guard AI latency (seconds, p50/p90)"], try(w.properties.title, ""))
    ])
    error_message = "Dependency percentiles need explicit, unique service/leg or service/operation labels, including bounded fallback legs."
  }

  assert {
    condition = length([for w in local.dashboard_body.widgets : w
      if try(w.properties.title, "") == "Retrieval failures per 5 minutes" &&
      strcontains(file("${path.module}/../../degradation_alarms.tf"), " ${try(w.properties.title, "")},")
    ]) == 1
    error_message = "The vector degradation alarm must name the existing retrieval-failures widget."
  }

  assert {
    condition = (
      length(local.diagnostics_body.widgets) == 7 &&
      local.diagnostics_body.start == "-PT1H" &&
      alltrue([for w in local.diagnostics_body.widgets :
        strcontains(w.properties.query, "SOURCE 'platform-logs-test'") &&
        strcontains(w.properties.query, "filter service = \"search\"") &&
        strcontains(w.properties.query, "limit 30") &&
        w.properties.view == "table"
        if w.type == "log"
      ]) && length(output.queries) == 6
    )
    error_message = "Diagnostics must use bounded search-only queries and remain available to the query validator."
  }

  assert {
    condition = (
      strcontains(output.queries["Recent Error Log"].query_string, "query_expansion_timed_out") &&
      strcontains(output.queries["Recent Error Log"].query_string, "event = \"api_call_completed\" and response_type = \"error\"") &&
      strcontains(output.queries["Recent Error Log"].query_string, "elapsed_ms, fallback_outcome, request_id")
    )
    error_message = "Recent errors must include timeout fallback and failed AI calls with diagnostic fields."
  }

  assert {
    condition = alltrue(flatten([
      for widgets in [local.dashboard_body.widgets, local.diagnostics_body.widgets] : [
        for i, a in widgets : [for j, b in widgets :
          i == j || a.x + a.width <= b.x || b.x + b.width <= a.x || a.y + a.height <= b.y || b.y + b.height <= a.y
        ]
      ]
    ]))
    error_message = "Dashboard widgets must not overlap."
  }

  assert {
    condition = (
      strcontains(local.dashboard_body.widgets[0].properties.markdown, "SearchOperations-test-Diagnostics") &&
      strcontains(local.diagnostics_body.widgets[0].properties.markdown, "SearchOperations-test)") &&
      !strcontains(aws_cloudwatch_dashboard.search_operations.dashboard_body, "request_id") &&
      !strcontains(aws_cloudwatch_dashboard.search_operations.dashboard_body, "error_message")
    )
    error_message = "Dashboards must link both ways and keep request identifiers and messages out of metrics."
  }
}

run "custom_name" {
  command = plan
  variables {
    dashboard_name = "CustomOperations"
  }
  assert {
    condition = (
      aws_cloudwatch_dashboard.search_diagnostics.dashboard_name == "CustomOperations-Diagnostics" &&
      strcontains(local.dashboard_body.widgets[0].properties.markdown, "CustomOperations-Diagnostics")
    )
    error_message = "Custom operation names must also control diagnostics names and links."
  }
}
