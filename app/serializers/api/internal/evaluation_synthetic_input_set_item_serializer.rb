module Api
  module Internal
    class EvaluationSyntheticInputSetItemSerializer
      include JSONAPI::Serializer

      set_type :evaluation_synthetic_input_set_item

      attributes :query, :oracle_text, :expected_code

      attribute :source_type do
        'synthetic_atar'
      end

      attribute :source_id do |item|
        item.synthetic_atar_id.to_s
      end

      attribute :persona do
        'raw'
      end
    end
  end
end
