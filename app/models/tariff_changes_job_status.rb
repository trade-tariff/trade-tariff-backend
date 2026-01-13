# frozen_string_literal: true

class TariffChangesJobStatus < Sequel::Model(Sequel[:tariff_changes_job_statuses].qualify(:public))
  plugin :auto_validations, not_null: :presence
  plugin :timestamps, update_on_create: true

  def self.for_date(date)
    find_or_create(operation_date: date.to_date)
  end

  def self.last_change_date
    where { changes_generated_at !~ nil }
      .order(Sequel.desc(:operation_date)).first&.operation_date
  end

  dataset_module do
    def pending_emails
      where { changes_generated_at !~ nil }
        .where { emails_sent_at =~ nil }
        .order(:operation_date)
        .select_map(:operation_date)
    end
  end

  def mark_changes_generated!
    update(changes_generated_at: Time.zone.now)
  end

  def mark_emails_sent!
    update(emails_sent_at: Time.zone.now)
  end
end
