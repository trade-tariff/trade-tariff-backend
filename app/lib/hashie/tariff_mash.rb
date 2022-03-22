module Hashie
  class TariffMash < Hashie::Mash
    disable_warnings

    # Need to wrap object in array because serializer gem does Array(obj) and it breaks Hashie::Mash object
    # See changes https://github.com/jsonapi-serializer/jsonapi-serializer/commit/f62a5bf1622fd2da0278e2fef0e8d4342b97e7cc
    def to_a
      Array.wrap(self)
    end

    # When using non-static serializers we need to avoid the jsonapi-serializer gem from treating a TariffMash like
    # an Array which it internally maps over to pull out ids and types from each record
    # when in fact each Mash should be treated like a single record.
    #
    # TODO: Replace Hashie::Mash with models and presenters since it does not play friendly with jsonapi-serializer
    def respond_to?(method)
      return false if method == :map

      super
    end
  end
end
