module Api
  module V2
    module RulesOfOrigin
      class LinkSerializer
        include JSONAPI::Serializer

        set_type :rules_of_origin_link

        set_id :id

        attributes :text, :url
      end
    end
  end
end
