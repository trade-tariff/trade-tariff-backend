# frozen_string_literal: true

Sequel.migration do
  up do
    create_table Sequel[:govuk_notifier_audits].qualify(:public), id: :uuid do
      primary_key :idid
      String :notification_uuid, null: false, unique: true
      String :subject, null: false
      String :body, null: false, text: true  
      String :from_email, null: false
      String :template_id, null: false
      String :template_version, null: false
      String :template_uri, null: false
      String :notification_uri, null: false
      DateTime :created_at
      DateTime :updated_at
    end
  end

  down do
    drop_table Sequel[:govuk_notifier_audits].qualify(:public)
  end
end
