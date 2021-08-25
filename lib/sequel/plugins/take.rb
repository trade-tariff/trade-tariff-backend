module Sequel
  class RecordNotFound < StandardError; end

  module Plugins
    module Take
      module DatasetMethods
        def take
          first.presence || (raise Sequel::RecordNotFound)
        end
      end
    end
  end
end
