module Api
  module Internal
    class EvaluationGoldQuerySerializer
      include JSONAPI::Serializer

      set_type :evaluation_gold_query

      attributes :source_type,
                 :source_id,
                 :persona,
                 :query,
                 :expected_code,
                 :expected_description,
                 :notes,
                 :generator,
                 :active,
                 :created_at
    end
  end
end
