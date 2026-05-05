require_relative '../app/helpers/materialize_view_helper'
# rubocop:disable Style/MixinUsage
include MaterializeViewHelper
# rubocop:enable Style/MixinUsage

# Populate materialized views after a db:structure:load. If any view was
# created WITH NO DATA, refresh! will detect "has not been populated" and
# fall back to a blocking refresh automatically.
refresh_materialized_view
