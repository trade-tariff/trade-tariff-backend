CREATE MATERIALIZED VIEW search_analytics_question_outcome_counts AS
WITH shown AS (
  SELECT DISTINCT service, reporting_date, journey_key, question_key
  FROM search_analytics_frontend_event_occurrences
  WHERE question_key IS NOT NULL
    AND (
      (outcome = 'page_visible' AND destination = 'question')
      OR (outcome = 'answer_accepted' AND response_source = 'server_accepted')
      OR outcome = 'dont_know'
    )
), responses AS (
  SELECT DISTINCT ON (service, reporting_date, journey_key, question_key)
    service,
    reporting_date,
    journey_key,
    question_key,
    CASE WHEN outcome = 'dont_know' THEN 'dont_know' ELSE 'server_accepted' END AS outcome
  FROM search_analytics_frontend_event_occurrences
  WHERE question_key IS NOT NULL
    AND (
      outcome = 'dont_know'
      OR (outcome = 'answer_accepted' AND response_source = 'server_accepted')
    )
  ORDER BY service, reporting_date, journey_key, question_key, observed_at DESC, outcome
)
SELECT shown.service,
  shown.reporting_date,
  COALESCE(responses.outcome, 'unanswered') AS outcome,
  COUNT(*)::bigint AS questions
FROM shown
LEFT JOIN responses USING (service, reporting_date, journey_key, question_key)
GROUP BY shown.service, shown.reporting_date, COALESCE(responses.outcome, 'unanswered')
WITH NO DATA;

CREATE UNIQUE INDEX search_analytics_question_outcome_counts_identity
  ON search_analytics_question_outcome_counts (service, reporting_date, outcome);
