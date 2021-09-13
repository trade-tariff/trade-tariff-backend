module Search
  class SectionSerializer < ::Serializer
    def serializable_hash(_opts = {})
      {
        id: id,
        numeral: numeral,
        title: title,
        declarable: false,
        position: position,
      }
    end
  end
end
