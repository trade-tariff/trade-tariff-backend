require 'ansi/progressbar'

module TradeTariffBackend
  class Auditor
    # Save memory - paginate records
    # Records per page
    cattr_accessor :per_page
    self.per_page = 1000

    # Audit logger
    # File is rewritten on each auditor run
    cattr_accessor :logger
    self.logger = Logger.new(File.open('log/audit.log', 'w+'))

    attr_reader :audit_file_name, :graphical

    def initialize(models = [],
                   since = nil,
                   audit_file_name = 'audit.log',
                   _graphical = true)
      @models = models.map { |model| model.classify.constantize }
      @since = Date.parse(since) if since.present?
      @audit_file_name = audit_file_name
      @graphical = true

      verify_models
    end

    def models
      @models.presence || Sequel::Model.subclasses.select { |model|
        model.plugins.include?(Sequel::Plugins::Oplog)
      }
    end

    def run
      models.each do |model|
        with_graphical_progress(model) do |progress_bar|
          model_invalid_record_count = 0
          date_filter(model).each_page(self.per_page) do |record_batch|
            record_batch.each do |record|
              if !record.valid?
                model_invalid_record_count += 1
                logger.error "Invalid #{model} (#{record.pk_hash}), errors: #{record.errors}"
              end

              progress_bar.inc
            end
          end

          progress_bar.finish

          if @since
            puts 'Invalid records for %s since %s: %d (%.4f%%)' % [model, @since, model_invalid_record_count, model_invalid_record_count / (model.count + 1).to_f]
          else
            puts 'Invalid records for %s: %d (%.4f%%)' % [model, model_invalid_record_count, model_invalid_record_count / (model.count + 1).to_f]
          end
        end
      end
    end

  private

    def date_filter(model)
      if @since.present? && model.columns.include?(:validity_start_date)
        model.dataset.filter { |o| o.validity_end_date <= @since }
      else
        model.dataset
      end
    end

    def with_graphical_progress(model)
      if graphical
        progress_bar = ::ANSI::Progressbar.new(model.to_s, date_filter(model).count)
        yield progress_bar
      else
        yield NullObject.new
      end
    end

    def verify_models
      models.empty? || models.all? { |model| model.is_a?(Sequel::Model) }
    end
  end
end
