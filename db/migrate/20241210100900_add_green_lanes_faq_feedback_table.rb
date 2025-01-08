# frozen_string_literal: true

Sequel.migration do
  change do
    unless table_exists?(:green_lanes_faq_feedback)
      create_table :green_lanes_faq_feedback do
        primary_key :id
        String :session_id, null: false
        Integer :category_id, null: false
        Integer :question_id, null: false
        Boolean :useful, null: false
        DateTime :created_at
        DateTime :updated_at
      end
    end

    alter_table :green_lanes_faq_feedback do
      add_unique_constraint [:session_id, :category_id, :question_id], name: :unique_faq_feedback
    end
  end
end
