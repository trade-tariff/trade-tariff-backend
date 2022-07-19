# frozen_string_literal: true

module RulesOfOrigin
  class Link
    include ActiveModel::Model
    include ContentAddressableId
    self.content_addressable_fields = %i[url text]

    attr_accessor :text, :url
    attr_writer :id

    class << self
      def new_with_check(attrs = {})
        attrs = attrs.stringify_keys
        return unless attrs['text'].present? && attrs['url'].present?

        new(attrs)
      end
    end
  end
end
