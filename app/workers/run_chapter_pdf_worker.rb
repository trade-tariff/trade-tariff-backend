require 'mailer_environment'

class RunChapterPdfWorker
  include Sidekiq::Worker

  sidekiq_options retry: 2

  def perform
    currency = TradeTariffBackend.currency

    batch = Sidekiq::Batch.new
    batch.description = "Produces PDFs for all chapters (in #{currency})"
    chapter_ids = Section.all.map(&:chapters).flatten.map(&:goods_nomenclature_sid)
    # chapter_ids = %w[47137 32338 54748] # <- short chapters

    if chapter_ids.empty?
      puts "Cancelled batch #{batch.bid}. No chapters were specified."
    else
      batch.on(:success, BatchCallback, bid: batch.bid, total: chapter_ids.size, start_time: Time.now.to_i, currency: currency)
      batch.jobs do
        GenerateCoverPdfWorker.perform_async(currency)
      end
      batch.jobs do
        chapter_ids.shuffle.each do |sid|
          GenerateChapterPdfWorker.perform_async(sid, currency)
        end
      end
    end
  end

  class BatchCallback
    def on_complete(status, options)
      if Rails.env.development?
        subject = "One or more PDF chapters were not created"
        message = "One or more PDF chapters were not created: #{status.failures}"
        email_results(subject, message, options)
        puts "Batch has #{status.failures} failures" if status.failures != 0
      end
    end

    def on_success(_status, options)
      currency = options['currency'] || 'EUR'
      if Rails.env.development?
        elapsed_time = Time.now.to_i - options['start_time']
        subject = "All Trade Tariff PDF chapters were created for #{currency}"
        message = "PDF chapters created (in #{currency}): #{options['total']} in #{elapsed_time} seconds."
        email_results(subject, message, options)
        puts "Batch #{options['bid']} succeeded in #{elapsed_time} seconds."
      end

      RunPdfCombinerWorker.perform_async(currency)
    end

    def email_results(subject, message, options)
      Mailer.pdf_generation_report(subject, message, options).deliver_now
    end
  end

  class Mailer < ActionMailer::Base
    include MailerEnvironment

    default from: TradeTariffBackend.from_email,
            to: TradeTariffBackend.admin_email

    def pdf_generation_report(subject, message, options)
      @options = options
      @message = message
      mail subject: "[#{subject_prefix}] #{subject}"
    end
  end
end
