# Backport from Rails 4
# https://github.com/rails/rails/blob/4-0-stable/activemodel/lib/active_model/model.rb

module ActiveModel
  module Model
    def self.included(base) #:nodoc:
      base.class_eval do
        extend  ActiveModel::Naming
        extend  ActiveModel::Translation
        include ActiveModel::Validations
        include ActiveModel::Conversion
      end
    end

    def initialize(params = {})
      if params
        params.each do |attr, value|
          self.public_send("#{attr}=", value)
        end
      end

      super()
    end

    def persisted?
      false
    end
  end
end
