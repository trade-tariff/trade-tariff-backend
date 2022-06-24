# frozen_string_literal: true

module RulesOfOrigin
  class Article
    include ActiveModel::Model

    attr_accessor :scheme, :article

    class << self
      def for_scheme(scheme)
        return [] unless articles_path(scheme).directory?

        articles_path(scheme).entries
                             .map(&:to_s)
                             .select { |f| f.ends_with? '.md' }
                             .map { |f| new scheme:, article: f.chomp('.md') }
      end

      private

      def articles_path(scheme)
        scheme.scheme_set.base_path.join('articles', scheme.scheme_code)
      end
    end

    def content
      @content ||= scheme.scheme_set.read_referenced_file('articles',
                                                          scheme.scheme_code,
                                                          "#{article}.md")
    end
  end
end
