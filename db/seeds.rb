require_relative '../app/helpers/materialize_view_helper'

# Populate materialized views after a db:structure:load. If any view was
# created WITH NO DATA, refresh! will detect "has not been populated" and
# fall back to a blocking refresh automatically.
MaterializeViewHelper.refresh_materialized_view
