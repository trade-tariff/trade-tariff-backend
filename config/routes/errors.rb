match '/400', to: 'errors#bad_request', via: :all
match '/404', to: 'errors#not_found', via: :all
match '/405', to: 'errors#method_not_allowed', via: :all
match '/406', to: 'errors#not_acceptable', via: :all
match '/422', to: 'errors#unprocessable_entity', via: :all
match '/500', to: 'errors#internal_server_error', via: :all
match '/501', to: 'errors#not_implemented', via: :all
match '/503', to: 'errors#maintenance', via: :all
