module RulesOfOrigin
  class Explainer
    include ActiveModel::Model

    attr_accessor :text, :url

    class << self
      def new_with_check(attrs = {})
        return unless attrs[:text].present? && attrs[:url].present?

        new(attrs)
      end
    end
  end
end
