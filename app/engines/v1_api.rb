class V1Api < ::Rails::Engine
end

V1Api.routes.draw do
  namespace :api, defaults: { format: 'json' }, path: '/' do
    scope module: :v1 do
      resources :sections, only: %i[index show] do
        collection do
          get :tree
        end
        scope module: 'sections', constraints: { id: /\d+/ } do
          resource :section_note, only: %i[show]
        end
      end

      resources :chapters, only: %i[index show], constraints: { id: /\d{2}/ } do
        member do
          get :changes
        end

        scope module: 'chapters', constraints: { chapter_id: /\d{2}/, id: /\d+/ } do
          resource :chapter_note, only: %i[show]
        end
      end

      resources :headings, only: [:show], constraints: { id: /\d{4}/ } do
        member do
          get :changes
        end
      end

      resources :commodities, only: [:show], constraints: { id: /\d{10}/, as_of: /.*/ } do
        member do
          get :changes
        end
      end

      get '/headings/:id/tree' => 'headings#tree'
    end
  end
end
