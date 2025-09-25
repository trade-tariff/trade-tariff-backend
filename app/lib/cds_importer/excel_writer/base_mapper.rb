class CdsImporter
  class ExcelWriter
    class BaseMapper

      def initialize(models)
        @models = models
      end

      attr_reader :models

      def expand_operation(model)
        text = ''
        if model.operation.present?
          case model.operation[0].upcase
          when 'C'
            text = 'Create a new'
          when 'U'
            text = 'Update an existing'
          when 'D'
            text = 'Delete a'
          end
        end
        text
      end

      def format_date(d)
        return "" if d.nil?
        d.strftime("%d/%m/%Y")
      end

      def format_date_ymd(d)
        return "" if d.nil?
        d.strftime("%Y-%m-%d")
      end

      def note
        nil
      end
    end
  end
end
