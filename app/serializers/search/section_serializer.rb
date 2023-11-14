module Search
  class SectionSerializer < ::Serializer
    def serializable_hash(_opts = {})
      {
        id:,
        numeral:,
        title:,
        position:,
      }
    end
  end
end
