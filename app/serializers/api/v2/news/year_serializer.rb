module Api
  module V2
    module News
      class YearSerializer
        include JSONAPI::Serializer

        set_type :news_year

        set_id :to_s

        attributes :year, &:to_i
      end
    end
  end
end
