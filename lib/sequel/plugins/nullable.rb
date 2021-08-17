module Sequel
  module Plugins
    module Nullable
      module DatasetMethods
        def first_or_null(*args)
          first(*args) || "Null#{model}".constantize.new
        end
      end
    end
  end
end
