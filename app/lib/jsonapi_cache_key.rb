module JsonapiCacheKey
  include JsonapiQueryOptions

  private

  def jsonapi_cache_key_suffix
    return if jsonapi_query_options.blank?

    cache_options = {}
    cache_options[:fields] = jsonapi_query_options[:fields] if jsonapi_query_options[:fields].present?
    cache_options[:include] = jsonapi_query_options[:include] if jsonapi_include_requested?
    return if cache_options.blank?

    Digest::MD5.hexdigest(cache_options.to_json)
  end

  def with_jsonapi_cache_key_suffix(cache_key)
    suffix = jsonapi_cache_key_suffix
    return cache_key if suffix.blank?

    "#{cache_key}/jsonapi-#{suffix}"
  end
end
