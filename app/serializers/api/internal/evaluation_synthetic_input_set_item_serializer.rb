module Api
  module Internal
    class EvaluationSyntheticInputSetItemSerializer
      include JSONAPI::Serializer

      set_type :evaluation_synthetic_input_set_item

      attributes :query, :expected_code

      # The item has only one text snapshot. A gold query row carries oracle_text
      # separately from query for the simulator to use as ground truth; here the same
      # value serves both, rather than omitting oracle_text or inventing a second field.
      attribute :oracle_text, &:query

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
