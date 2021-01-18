require 'combine_pdf'
require 'net/http'

class RunPdfCombinerWorker
  include Sidekiq::Worker
  include PaasS3

  sidekiq_options retry: 2

  def perform(currency = 'EUR')
    @dir = ENV['AWS_PDF_ROOT_PATH'] || ''
    @key = ENV['AWS_PDF_FILENAME'] || "UK-Trade-Tariff-#{Date.today.strftime('%d-%m-%Y')}.pdf"
    @cur = currency.downcase
    initialize_s3(s3_file_path)
    setup_ephemeral_directory
    create_combined_pdf
    upload_to_s3
    verify_on_s3
    delete_from_ephemeral
    email_results
  end

  private

  def latest_filename
    File.join(@cur, 'UK-Trade-Tariff-latest.pdf')
  end

  def setup_ephemeral_directory
    dir = File.join(Rails.root, 'public', 'pdf', 'tariff', @cur)
    return if File.exist?(dir)

    FileUtils.mkpath(dir)
  end

  def create_combined_pdf
    pdf = CombinePDF.new
    @chapters = bucket.objects(prefix: bucket_prefix).collect(&:key)
    @chapters.each do |key|
      url = bucket.object(key).presigned_url(:get)
      pdf << CombinePDF.parse(Net::HTTP.get_response(URI.parse(url)).body)
    end
    pdf.save ephemeral_file_path
  end

  def ephemeral_file_path
    File.join(Rails.root, 'public', 'pdf', 'tariff', @cur, @key)
  end

  def s3_file_path
    File.join(@dir, @cur, @key).gsub(%r{^/}, '')
  end

  def bucket_prefix
    File.join(@dir, 'chapters', @cur).gsub(%r{^/}, '')
  end

  def upload_to_s3
    File.open(ephemeral_file_path, 'rb') do |pdf|
      @s3_obj.put(body: pdf)
      @bucket.object(latest_filename).upload_file(pdf)
    end
  end

  def verify_on_s3
    if @s3_obj.exists?
      logger.info "PDF saved on S3: #{s3_file_path}"
    else
      logger.info "File '#{s3_file_path}' is not in s3 bucket!"
    end
  end

  def delete_from_ephemeral
    File.delete(ephemeral_file_path) if File.exist?(ephemeral_file_path)
  end

  def email_results
    public_url = @s3_obj.public_url
    subject = 'The Trade Tariff PDF was produced'
    message = "#{@chapters.size} chapters were combined into a single PDF (in #{@cur.upcase}). (#{public_url})"
    options = { key: s3_file_path, public_url: public_url }
    Mailer.pdf_generation_report(subject, message, options).deliver_now
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
