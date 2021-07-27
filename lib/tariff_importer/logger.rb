module TariffImporter
  class Logger < ActiveSupport::LogSubscriber
    def taric_failed(event)
      "Taric import failed: #{event.payload[:exception]}".tap { |message|
        message << "\n Failed transaction:\n #{event.payload[:hash]}"
        message << "\n Backtrace:\n #{event.payload[:exception].backtrace.join("\n")}"
        error message
      }
    end

    def taric_imported(event)
      info "Successfully imported Taric file: #{event.payload[:filename]}"
    end

    def taric_unexpected_update_type(event)
      error "Unexpected Taric operation type: #{event.payload[:record].inspect}"
    end

    def cds_failed(event)
      "Cds import failed: #{event.payload[:exception]}".tap {|message|
        message << "\n Failed object: #{event.payload[:key]}\n #{event.payload[:hash]}"
        message << "\n Backtrace:\n #{event.payload[:exception].backtrace.join("\n")}"
        error message
      }
    end

    def cds_imported(event)
      info "Successfully imported Cds file: #{event.payload[:filename]}"
    end
  end
end

TariffImporter::Logger.attach_to :tariff_importer
