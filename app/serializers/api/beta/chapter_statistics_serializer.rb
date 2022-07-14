module Api
  module Beta
    class ChapterStatisticsSerializer
      include JSONAPI::Serializer

      set_type :chapter_statistic

      attributes :description,
                 :cnt,
                 :score,
                 :avg
    end
  end
end
