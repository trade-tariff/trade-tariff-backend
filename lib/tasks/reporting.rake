namespace :reporting do
  desc 'Generate all reports except differences report'
  task generate_daily_reports: :environment do
    ReportWorker.perform_async(false)
  end

  desc 'Generate differences report, add NOEMAIL=true to not send email'
  task generate_differences_report: :environment do
    DifferencesReportWorker.perform_async(ENV['NOEMAIL'] != 'true')
  end

  desc 'Generate FAQ Feedback report , add NOEMAIL=true to not send email'
  task generate_faq_feedback_report: :environment do
    FaqFeedbackReportWorker.perform_async(ENV['NOEMAIL'] != 'true')
  end

  desc 'Backfill missing Monday differences reports from the last 30 days, add DRY_RUN=true to preview only'
  task backfill_differences_reports: :environment do
    summary = Reporting::BackfillDifferencesReports.new(
      dry_run: ENV['DRY_RUN'] == 'true',
      send_email: ENV['NOEMAIL'] != 'true',
    ).call

    puts "Uploaded: #{summary[:uploaded].map(&:iso8601).join(', ')}" if summary[:uploaded].any?
    puts "Emailed: #{summary[:emailed].map(&:iso8601).join(', ')}" if summary[:emailed].any?
    puts "Email skipped: #{summary[:email_skipped].map(&:iso8601).join(', ')}" if summary[:email_skipped].any?
    puts "Planned uploads: #{summary[:planned_uploads].map(&:iso8601).join(', ')}" if summary[:planned_uploads].any?
    puts "Planned emails: #{summary[:planned_emails].map(&:iso8601).join(', ')}" if summary[:planned_emails].any?
  end
end
