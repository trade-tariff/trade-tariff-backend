# search_sample_dashboard

CloudWatch Logs Insights dashboard for comparing Flagsmith-offered frontend search (`experiment = tenpct`) with unlabelled frontend search (control).

Sample is assignment, not use of guided search. Classic volume inside `tenpct` is expected. Control is not a clean 90% of users: it includes traffic from before the stamp, Flagsmith fallbacks, and unlabelled browsers. URL enrolments stay on Search Experiment.

Search totals and rates collapse to one row per `request_id` before aggregation. Distinct guided-search browser sessions are estimated for the selected window only and are not additive across hours. Query text is not displayed. Refresh is manual because each widget starts a new Logs Insights scan.

The empty-result predicates match Search Overview, Quality, and Experiment.
