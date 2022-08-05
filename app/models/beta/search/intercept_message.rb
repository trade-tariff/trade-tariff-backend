module Beta
  module Search
    class InterceptMessage
      include ContentAddressableId

      content_addressable_fields :term, :message

      attr_accessor :term, :message

      def self.build(search_query)
        query = search_query.downcase

        return unless query.eql?(I18n.t("#{query}.title"))

        result = new

        result.term = I18n.t("#{query}.title")
        result.message = I18n.t("#{query}.message")

        result
      end
    end
  end
end
