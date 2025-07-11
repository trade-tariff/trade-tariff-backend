# frozen_string_literal: true

Sequel.migration do
  up do
    unless Sequel::Model.db.table_exists?(Sequel[:enquiry_form_submissions].qualify(:public))
      create_table Sequel[:enquiry_form_submissions].qualify(:public) do
        primary_key :id
        String :reference_number, null: false, unique: true
        String :email_status, null: false, default: 'Pending'
        String :csv_url
        DateTime :created_at
        DateTime :updated_at
        DateTime :submitted_at
      end
    end
  end

  down do
    if Sequel::Model.db.table_exists?(Sequel[:enquiry_form_submissions].qualify(:public))
      drop_table Sequel[:enquiry_form_submissions].qualify(:public)
    end
  end
end
