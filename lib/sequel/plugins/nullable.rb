module Sequel
  module Plugins
    module Nullable
      module DatasetMethods
        def first_or_null(*args)
          null_model = "Null#{model}"

          require null_model.underscore

          first(*args) || null_model.constantize.new
        end
      end
    end
  end
end
