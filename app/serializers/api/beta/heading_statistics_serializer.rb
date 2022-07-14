module Api
  module Beta
    class HeadingStatisticsSerializer
      include JSONAPI::Serializer

      set_type :heading_statistic

      attributes :description,
                 :chapter_id,
                 :chapter_description,
                 :score,
                 :cnt,
                 :avg,
                 :chapter_score
    end
  end
end
