class CdsSnapshotImporter
  class ImportException < StandardError
    attr_reader :original

    def initialize(msg = 'CdsImporter::ImportException', original = $ERROR_INFO)
      super(msg)
      @original = original
    end
  end

  def initialize(update)
    @update = update
  end

  def import
    Rails.application.eager_load!
    Sequel::Plugins::Oplog.registered_models.each_value(&:truncate)

    start_time = Time.zone.now
    handler = XmlProcessor.new(@update.filename)
    zip_file = TariffSynchronizer::FileService.file_as_stringio(@update)

    Zip::File.open_buffer(zip_file) do |archive|
      archive.entries.each do |entry|
        wrapped_stream = ProgressIo.new(
          entry.get_input_stream,
          total_size: entry.size,
          label: "Processing #{entry.name}",
          log_every: 0.1,
          start_time:,
        )
        CdsImporter::XmlParser::Reader.new(wrapped_stream, handler).parse
        handler.process_end
        Rails.logger.info "Successfully imported Cds Annual file: #{@update.filename}"
      end
    end
  end

  class XmlProcessor
    def initialize(filename)
      @filename = filename
      @types = Hash.new(0)
      @count = 0
      @batch = Hash.new([])
      @current_primary = ''
    end

    # The XML has sections of responses where all of the primary's are the same type.
    #    e.g. Measure, Measure, Measure, Measure, QuotaOrderNumber, QuotaOrderNumber, QuotaOrderNumber
    #
    # We instantiate a new batch when:
    #
    # 1. The current node is different from the previous node (e.g. we used to be iterating over 'Measure' nodes and now we're iterating over 'QuotaOrderNumber' nodes)
    # 2. We've reached the batch size
    # 3. We've reached the end of the file (signified by a call to process_end)
    #
    # All of the batches we accumulate for the primary and secondary nodes will have different lengths
    def process_xml_node(key, hash_from_node)
      hash_from_node['filename'] = @filename

      process_batch if @batch.any? && @current_primary != key || (@count % TradeTariffBackend.snapshot_importer_batch_size).zero?

      @current_primary = key
      @count += 1

      CdsImporter::EntityMapper.new(key, hash_from_node).parse do |model, _mapper|
        @types[model.class] += 1
        @batch[model.class] << model
      end
    rescue StandardError => e
      cds_failed_log(e, key, hash_from_node)
      raise ImportException
    end

    def process_batch
      @batch.each do |model_klass, batch|
        model_klass.operation_klass.multi_insert(batch.map(&:values))
      end

      @batch = Hash.new([])
    end

    alias_method :process_end, :process_batch

    def cds_failed_log(exception, key, hash)
      message = "Cds import failed: #{exception}"
      message << "\n Failed object: #{key}\n #{hash}"
      message << "\n Backtrace:\n #{exception.backtrace.join("\n")}"
      Rails.logger.error(message)
    end
  end
end
