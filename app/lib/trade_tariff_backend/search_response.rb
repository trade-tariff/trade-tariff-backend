module TradeTariffBackend
  # Wraps a raw OpenSearch response hash, providing explicit access to the
  # fields callers actually need. Does not inherit from Hash or include
  # Enumerable, so jsonapi-serializer treats it as a single record rather
  # than a collection.
  class SearchResponse
    def initialize(data)
      @data = data
    end

    delegate :[], to: :@data

    def dig(*keys)
      @data.dig(*keys)
    end

    def error?
      @data.key?('error')
    end

    def error
      @data['error']
    end

    # Returns an array of SearchResponse objects, one per msearch response.
    def responses
      (@data['responses'] || []).map { |r| self.class.new(r) }
    end

    # Returns a SearchResponse wrapping the hits hash, or nil when absent.
    def hits
      return nil unless @data.key?('hits')

      value = @data['hits']
      value.is_a?(Hash) ? self.class.new(value) : value
    end

    # Like #hits but raises KeyError when the key is absent.
    def hits!
      raise KeyError, "'hits' not found in OpenSearch response" unless @data.key?('hits')

      value = @data['hits']
      value.is_a?(Hash) ? self.class.new(value) : value
    end
  end
end
