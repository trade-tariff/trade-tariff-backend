# Use this when you are happy for the endpoint to be cached
# but once the cache lifetime expires (expected to be 5 minutes) you always want
# the data to be reloaded
#
# Useful to ease high request counts

module SimpleCaching
  protected

  def set_cache_etag; end
end
