class GenerateChapterPdfWorker
  include Sidekiq::Worker

  sidekiq_options retry: 3

  def self.chapter_pdf(chapter_sid, save_immediately = false)
    chapter = Chapter.eager(:headings).where(goods_nomenclature_sid: chapter_sid).take
    pdf_name = "#{chapter.section.position.to_s.rjust(2, '0')}-#{chapter.short_code}-#{chapter.formatted_description}.pdf"
    pdf = ExportChapterPdf.new(chapter)
    return pdf unless save_immediately

    pdf.save_as(pdf_name)
  end

  def perform(chapter_sid, currency = 'EUR')
    setup_chapter_object(chapter_sid, currency)

    make_logger

    generate_and_upload
  end

  def setup_chapter_object(chapter_sid, currency)
    @chapter = Chapter.eager(:headings).where(goods_nomenclature_sid: chapter_sid).take
    file_name = "#{@chapter.section.position.to_s.rjust(2, '0')}-#{@chapter.short_code}.pdf"
    @currency = currency
    @pdf_file_path = File.join('public', 'pdf', 'tariff', 'chapters', @currency.downcase, file_name)
    @dir, @base = File.split(@pdf_file_path)
    return if File.exist?(@dir)

    begin
      FileUtils.mkpath(@dir)
    rescue SystemCallError => e
      logger.warn e
    end
  end

  def make_logger
    log_dir = File.join(Rails.root, 'log', 'pdf')
    unless File.exist?(log_dir)
      begin
        FileUtils.mkpath(log_dir)
      rescue SystemCallError => e
        logger.warn e
      end
    end
    @logger ||= Logger.new(File.join(log_dir, "#{batch.bid}.log"))
    @logger.progname = batch.bid
  end

  def generate_and_upload
    if File.directory?(@dir)
      make_chapter_pdf
      queue_for_upload
    else
      logger.info "PDF #{@base} failed: Could not find #{@dir}"
    end
  end

  def make_chapter_pdf
    start = Time.now.to_i
    pdf = Uktt::Pdf.new
    pdf.config = { chapter_id: @chapter.short_code,
                   filepath: @pdf_file_path,
                   host: 'https://www.trade-tariff.service.gov.uk/api',
                   currency: @currency }
    logger.info "PDF started: #{@pdf_file_path}"
    pdf.make_chapter
    logger.info "PDF saved locally: #{@pdf_file_path}"
    log_completed(start)
  end

  def log_completed(start)
    @logger.info [@chapter.short_code,
                  @chapter.goods_nomenclature_sid,
                  (Time.now.to_i - start)]
  end

  def queue_for_upload
    if File.exist?(@pdf_file_path)
      UploadChapterPdfWorker.new.perform(@pdf_file_path, @currency)
    else
      logger.error "#{@pdf_file_path} not found"
    end
  end
end
