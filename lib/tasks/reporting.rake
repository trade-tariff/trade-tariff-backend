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
end
