module Search
  class SectionSerializer < ::Serializer
    def serializable_hash(_opts = {})
      {
        id: id,
        numeral: numeral,
        title: title,
        position: position
      }
    end
  end
end
