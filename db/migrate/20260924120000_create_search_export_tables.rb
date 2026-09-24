# frozen_string_literal: true

# Sequel declares timestamps explicitly; clicks need only their event timestamp.
# rubocop:disable Metrics/BlockLength, Rails/CreateTableWithTimestamps
Sequel.migration do
  change do
    create_table :search_export_journeys do
      primary_key :id
      String :request_id, null: false, unique: true
      String :service, null: false
      String :request_source, null: false
      String :query, null: false, text: true
      jsonb :expansion_terms, null: false, default: '[]'
      jsonb :answers, null: false, default: '[]'
      String :end_page_type, null: false
      jsonb :results, null: false, default: '[]'
      TrueClass :omitted, null: false, default: false
      DateTime :terminal_at, null: false
      DateTime :created_at, null: false
      DateTime :updated_at, null: false

      index %i[service request_source terminal_at]
    end

    create_table :search_export_result_clicks do
      primary_key :id
      String :request_id, null: false
      String :commodity_code, null: false
      Integer :result_rank
      DateTime :clicked_at, null: false

      index %i[request_id clicked_at]
    end

    create_table :search_export_workbooks do
      primary_key :id
      String :service, null: false
      Date :from_date, null: false
      Date :to_date, null: false
      String :status, null: false
      Integer :omitted_count
      Integer :row_count
      String :error_message, text: true
      File :file
      String :whodunnit
      DateTime :created_at, null: false
      DateTime :updated_at, null: false
    end
  end
end
# rubocop:enable Metrics/BlockLength, Rails/CreateTableWithTimestamps
