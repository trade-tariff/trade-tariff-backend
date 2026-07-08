class V1Api < ::Rails::Engine
end

module V1ApiRoutes
  def draw_v1_catalogue_routes
    resources :sections, only: %i[index show] do
      collection { get :tree }
      scope module: 'sections', constraints: { id: /\d+/ } do
        resource :section_note, only: %i[show]
      end
    end

    resources :chapters, only: %i[index show], constraints: { id: /\d{2}/ } do
      member { get :changes }
      scope module: 'chapters', constraints: { chapter_id: /\d{2}/, id: /\d+/ } do
        resource :chapter_note, only: %i[show]
      end
    end
  end

  def draw_v1_goods_routes
    resources :headings, only: [:show], constraints: { id: /\d{4}/ } do
      member { get :changes }
    end

    resources :commodities, only: [:show], constraints: { id: /\d{10}/, as_of: /.*/ } do
      member { get :changes }
    end

    get '/headings/:id/tree' => 'headings#tree'
  end

  def draw_v1_error_routes
    match '/400', to: 'errors#bad_request', via: :all
    match '/404', to: 'errors#not_found', via: :all
    match '/405', to: 'errors#method_not_allowed', via: :all
    match '/406', to: 'errors#not_acceptable', via: :all
    match '/422', to: 'errors#unprocessable_content', via: :all
    match '/500', to: 'errors#internal_server_error', via: :all
    match '/501', to: 'errors#not_implemented', via: :all
    match '/503', to: 'errors#maintenance', via: :all
  end
end

V1Api.routes.draw do
  extend V1ApiRoutes

  namespace :api, defaults: { format: 'json' }, path: '/' do
    scope module: :v1 do
      draw_v1_catalogue_routes
      draw_v1_goods_routes
      draw_v1_error_routes
    end
  end
end
