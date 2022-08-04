module Beta
  module Search
    class InterceptMessage
      include ContentAddressableId

      content_addressable_fields :intercept_message

      attr_accessor :intercept_message, :term, :message

      def self.build(search_query)
        query = search_query.downcase

        return unless query.eql?((I18n.t "#{query}.title"))

        result = new

        result.term = I18n.t "#{query}.title"
        result.message = I18n.t "#{query}.message"

        result
      end
    end
  end
end
