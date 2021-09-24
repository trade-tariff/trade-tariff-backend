# frozen_string_literal: true

require 'digest'

module RulesOfOrigin
  class Link
    include ActiveModel::Model

    attr_accessor :text, :url
    attr_writer :id

    class << self
      def new_with_check(attrs = {})
        attrs = attrs.stringify_keys
        return unless attrs['text'].present? && attrs['url'].present?

        new(attrs)
      end
    end

    def id
      @id ||= Digest::MD5.hexdigest("#{url}-#{text}")
    end
  end
end
