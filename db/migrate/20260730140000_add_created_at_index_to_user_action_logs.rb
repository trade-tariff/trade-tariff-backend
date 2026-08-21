# frozen_string_literal: true

# ActionLogReportWorker filters user_action_logs by created_at range (≈1 month).
# Without an index, that query degrades to a sequential scan as the table grows.
Sequel.migration do
  up do
    run <<~SQL
      CREATE INDEX IF NOT EXISTS user_action_logs_created_at_index
        ON public.user_action_logs (created_at);
    SQL
  end

  down do
    run <<~SQL
      DROP INDEX IF EXISTS public.user_action_logs_created_at_index;
    SQL
  end
end
