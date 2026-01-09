# frozen_string_literal: true

Sequel.migration do
  change do
    unless Sequel::Model.db.table_exists?(Sequel[:tariff_changes_job_statuses].qualify(:public))
      create_table Sequel[:tariff_changes_job_statuses].qualify(:public) do
        primary_key :id
        Date :operation_date, null: false, unique: true
        DateTime :changes_generated_at
        DateTime :emails_sent_at
        DateTime :created_at
        DateTime :updated_at

        index :operation_date, unique: true
      end
    end
  end
end
