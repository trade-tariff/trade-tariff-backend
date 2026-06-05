FactoryBot.define do
  factory :customs_tariff_pipeline_event do
    event_type { 'import' }
    outcome { 'succeeded' }
    customs_tariff_update_version { '1.1' }
    subject_type { 'CustomsTariffUpdate' }
    subject_id { customs_tariff_update_version }
    whodunnit { 'operator@example.gov.uk' }
    occurred_at { Time.zone.local(2026, 6, 5, 10, 0, 0) }
    duration_ms { 1250 }
    records_total { 10 }
    records_succeeded { 10 }
    records_failed { 0 }
    records_pending { 0 }
    metadata { { 'source_url' => 'https://example.com/tariff.docx' } }
  end

  factory :customs_tariff_pipeline_metric_bin do
    bucket_size { 'hour' }
    bucket_start_at { Time.zone.local(2026, 6, 5, 10, 0, 0) }
    metric_name { 'import_runs' }
    customs_tariff_update_version { 'all' }
    event_type { 'import' }
    outcome { 'succeeded' }
    note_type { 'all' }
    count { 1 }
    value_sum { 1250 }
    value_min { 1250 }
    value_max { 1250 }
    value_last { 1250 }
    metadata { { 'unit' => 'milliseconds' } }
  end

  factory :customs_tariff_pipeline_alert do
    alert_type { 'failed_import' }
    severity { 'critical' }
    status { 'open' }
    customs_tariff_update_version { '1.1' }
    metric_name { 'import_runs' }
    bucket_start_at { Time.zone.local(2026, 6, 5, 10, 0, 0) }
    triggered_at { Time.zone.local(2026, 6, 5, 10, 5, 0) }
    threshold_value { 0 }
    observed_value { 1 }
    message { 'Customs tariff document import failed' }
    metadata { { 'error_code' => 'document_parse_failed' } }
  end
end
