module Api
  module V2
    module RulesOfOrigin
      class ArticleSerializer
        include JSONAPI::Serializer

        set_type :rules_of_origin_article

        attributes :article, :content
      end
    end
  end
end
