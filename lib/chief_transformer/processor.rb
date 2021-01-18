Dir[File.join(Rails.root, 'lib', 'chief_transformer/operations/*.rb')].each { |f| require f }

class ChiefTransformer
  class Processor
    attr_reader :operations

    def initialize(*operations)
      @operations = operations.flatten.sort_by { |record| [record.audit_tsmp, record.fe_tsmp] }
    end

    def process
      operations.each do |operation|
        ActiveSupport::Notifications.instrument('process.chief_transformer', operation: operation) do
          Sequel::Model.db.transaction do
            begin
              operator_for(operation).new(operation).process

              operation.mark_as_processed!
            rescue Sequel::ValidationFailed => exception
              ActiveSupport::Notifications.instrument('invalid_operation.chief_transformer', operation: operation,
                                                                                             exception: exception,
                                                                                             model: exception.model,
                                                                                             errors: exception.errors)

              raise ChiefTransformer::TransformException.new("Could not transform: #{operation.inspect}. \nModel: #{exception.model.inspect}. \nErrors: #{exception.errors.inspect} \nBacktrace: \n#{exception.backtrace.join("\n")}", exception)
            rescue StandardError => exception
              ActiveSupport::Notifications.instrument('invalid_operation.chief_transformer', operation: operation,
                                                                                             exception: exception)

              raise ChiefTransformer::TransformException.new("Could not transform: #{operation.inspect}. \n #{exception} \nBacktrace: \n#{exception.backtrace.join("\n")}", exception)
            end
          end
        end
      end
    end

  private

    def operator_for(operation)
      ['ChiefTransformer::Processor',
       operation_name(operation)].join('::').constantize
    end

    def operation_name(operation)
      operation.class.name.demodulize.tap! { |name|
        name << case operation.amend_indicator
                when 'I'
                  'Insert'
                when 'X'
                  'Delete'
                when 'U'
                  'Update'
                else
                  'Insert'
                end
      }
    end
  end
end
