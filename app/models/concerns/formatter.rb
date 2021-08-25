module Formatter
  extend ActiveSupport::Concern

  module ClassMethods
    def format(attribute, options)
      options.assert_valid_keys :with, :using, :defaults

      formatter, using, defaults = options.values_at(:with,
                                                     :using,
                                                     :defaults)
      mod = Module.new do
        define_method(attribute) do
          opts = {}

          [using].flatten.each do |field|
            opts[field] = result_of_attribute_or_method_call(field)
          end if using.present?

          formatter.format(opts)
        end

        # Meaningful name for formatter module in ancestor chain
        def self.inspect
          'Formatter'
        end
      end

      include mod
    end
  end

  private

  def result_of_attribute_or_method_call(field_name)
    self[field_name.to_s].presence ||
      (send(field_name) if respond_to?(field_name)).presence ||
      ''
  end
end
