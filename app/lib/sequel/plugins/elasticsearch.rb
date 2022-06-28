# Index models in Elasticsearch after create/update and remove from index
# after destroy
module Sequel
  module Plugins
    module Elasticsearch
      module InstanceMethods
        def after_create
          super

          TradeTariffBackend.search_client.index(self)
        end

        def after_update
          super

          TradeTariffBackend.search_client.index(self)
        end

        def after_destroy
          super

          TradeTariffBackend.search_client.delete(self)
        rescue ::Elasticsearch::Transport::Transport::Errors::NotFound
        end
      end
    end
  end
end
