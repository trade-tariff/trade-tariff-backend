module Hashie
  class TariffMash < Hashie::Mash
    disable_warnings

    # Need to wrap object in array because serializer gem does Array(obj) and it breaks Hashie::Mash object
    # See changes https://github.com/jsonapi-serializer/jsonapi-serializer/commit/f62a5bf1622fd2da0278e2fef0e8d4342b97e7cc
    def to_a
      Array.wrap(self)
    end
  end
end
