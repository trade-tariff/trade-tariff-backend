# After a rake db:structure:load Materialized Views are unpopulated, causing
# any concurrent refreshes to fail. Populating here should help avoid that.
GoodsNomenclatures::TreeNode.refresh!(concurrently: false)

# For API access
dummy_api_user = User.new
dummy_api_user.email = 'dummyapiuser@domain.com'
dummy_api_user.uid = rand(10_000).to_s
dummy_api_user.name = 'Dummy API user created by gds-sso'
dummy_api_user.permissions = %w[signin]
dummy_api_user.save
