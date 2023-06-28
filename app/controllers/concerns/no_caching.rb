module NoCaching
  protected

  def set_cache_headers
    no_store
  end
end
