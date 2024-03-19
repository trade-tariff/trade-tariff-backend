Sequel.default_timezone = :utc
Sequel.extension :pg_json
Sequel.extension :connection_validator
Sequel.split_symbols = true

# TimeMachine is incompatible with caching of associations dataset objects. This
# is due to the cached dataset object including the TimeMachine date in it,
# which may change between queries.
#
# Previously there was a work-around to clear these objects on most models
# in the controller actions _but_ that doesn't solve the issue for background
# jobs running in Redis, and will be potentially missed as new TimeMachine
# aware data models are added.

# Since creation of these dataset objects should be very fast I'm assuming this
# is a micro-optimisation to avoid constantly recreating dataset objects which
# will in turn needs GCing. Ruby's GC behaviour has significantly improved in
# the last few years so I doubt this will have much impact today
#
# This also turns on reloading of db schema for each model at class load, ie at
# boot in a production app. Whilst this is unnecessary for our use case, turning
# this off doesn't offer enough benefit to justify monkey patching Sequel::Model
Sequel::Model.cache_associations = false
