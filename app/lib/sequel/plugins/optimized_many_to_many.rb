# lib/sequel/plugins/optimized_many_to_many.rb
require_relative 'optimized_many_to_many/sql_helpers'
require_relative 'optimized_many_to_many/eager_loader'
require_relative 'optimized_many_to_many/class_methods'

module Sequel
  module Plugins
    module OptimizedManyToMany
      EagerLoadQuery = Data.define(:sql, :bind_args, :left_keys, :left_pks)

      extend SqlHelpers
      extend EagerLoader
    end
  end
end
