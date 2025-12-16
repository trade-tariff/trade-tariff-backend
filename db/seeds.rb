require_relative '../app/helpers/materialize_view_helper'
# rubocop:disable Style/MixinUsage
include MaterializeViewHelper
# rubocop:enable Style/MixinUsage

# After a rake db:structure:load Materialized Views are unpopulated, causing
# any concurrent refreshes to fail. Populating here should help avoid that.
refresh_materialized_view
