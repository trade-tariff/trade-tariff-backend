# The generator writes three gold queries (one per persona) for every source item of a
# set. This creates the same three rows, so a spec can start from a realistic item.
module GoldQueryItemHelper
  def create_gold_query_item(gold_query_set, source_type: 'atar', source_id: '600000001', expected_code: '6302100000', queries: {})
    Evaluation::GoldQueryGenerator::PERSONA_FOR_TIER.values.map do |persona|
      create(
        :evaluation_gold_query,
        evaluation_gold_query_set: gold_query_set,
        source_type:,
        source_id:,
        persona:,
        expected_code:,
        query: queries.fetch(persona, "#{persona} search"),
      )
    end
  end
end
