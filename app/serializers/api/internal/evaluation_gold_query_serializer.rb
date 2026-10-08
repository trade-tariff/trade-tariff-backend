module Api
  module Internal
    class EvaluationGoldQuerySerializer
      include JSONAPI::Serializer

      set_type :evaluation_gold_query

      attributes :set_id,
                 :source_type,
                 :source_id,
                 :persona,
                 :query,
                 :expected_code,
                 :expected_code_digits,
                 :expected_description,
                 :oracle_text,
                 :notes,
                 :generator,
                 :active,
                 :created_at
    end
  end
end
