class UploadChapterPdfWorker
  include Sidekiq::Worker
  include PaasS3

  sidekiq_options queue: :sync, retry: false

  def perform(pdf_file_path, currency = 'EUR')
    @cur = currency.downcase
    @dir, @key = File.split(pdf_file_path)
    initialize_s3(s3_file_path)
    upload_to_s3
    verify_on_s3
    delete_from_ephemeral
  end

  private

  def ephemeral_file_path
    File.join(@dir, @key)
  end

  def s3_file_path
    File.join(ENV['AWS_PDF_ROOT_PATH'].to_s, 'chapters', @cur, @key).gsub(%r{^/}, '')
  end

  def upload_to_s3
    File.open(ephemeral_file_path, 'rb') do |pdf|
      @s3_obj.put(body: pdf)
    end
  end

  def verify_on_s3
    if @s3_obj.exists?
      logger.info "PDF saved on S3: #{s3_file_path}"
    else
      logger.info "File '#{s3_file_path}' is not in S3 bucket!"
    end
  end

  def delete_from_ephemeral
    File.delete(ephemeral_file_path) if File.exist?(ephemeral_file_path)
  end
end
