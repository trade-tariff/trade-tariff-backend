Sequel.migration do
  change do
    alter_table(:evaluation_results) do
      # True unless at least one LLM call behind this result used a model missing from
      # config/openai_model_pricing.yml (AiUsage::PricingCalculator#pricing_known?) — cost_usd
      # still accumulates whatever partial cost *was* priceable, so this flags "this total may be
      # incomplete" rather than hiding the number outright. Defaults true: every result recorded
      # before this column existed used a model this project has always had priced.
      add_column :pricing_known, :boolean, null: false, default: true
    end

    alter_table(:evaluation_runs) do
      # How many of this run's results have pricing_known = false — surfaced so the run summary
      # can warn "N results have unknown pricing, total cost may be understated" instead of
      # silently showing a total that looks complete but isn't.
      add_column :unpriced_result_count, :integer, null: false, default: 0
    end
  end
end
