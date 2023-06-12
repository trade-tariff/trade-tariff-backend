module Cache
  class CacheIndex < ::SearchIndex
    def name
      "#{super}-cache"
    end

    def page_size
      5
    end
  end
end
