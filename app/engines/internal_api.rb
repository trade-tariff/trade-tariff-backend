class InternalApi < ::Rails::Engine
end

InternalApi.routes.draw do
  namespace :api, defaults: { format: 'json' }, path: '' do
    scope module: :internal do
      post 'search' => 'search#search'
      get 'search' => 'search#search'
      get 'search_suggestions' => 'search#suggestions'

      # ATaR rulings (and the gold queries generated from them) are a UK/HMRC-specific
      # data source — XI has no equivalent, so both stay behind the same UK-only guard.
      if TradeTariffBackend.uk?
        resources :atars, only: %i[index show], param: :ref
        resources :evaluation_gold_queries, only: %i[index show]
      end
    end
  end
end
