# frozen_string_literal: true

Sequel.migration do
  up do
    # Get all unique operation dates from tariff changes
    operation_dates = TariffChange.pluck(:operation_date).uniq

    operation_dates.each do |operation_date|
      next_day_midnight = (operation_date + 1.day).beginning_of_day

      TariffChangesJobStatus.find_or_create(operation_date: operation_date) do |status|
        status.changes_generated_at = next_day_midnight
        status.emails_sent_at = next_day_midnight
      end
    end

    Rails.logger.info("Created #{operation_dates.count} TariffChangesJobStatus records")
  end

  down do
    TariffChangesJobStatus.dataset.delete
    Rails.logger.info("Removed all TariffChangesJobStatus records")
  end
end
