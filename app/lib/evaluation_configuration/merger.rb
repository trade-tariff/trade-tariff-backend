module EvaluationConfiguration
  class Merger
    def self.call(baseline, *override_layers)
      override_layers.compact.reduce(baseline) { |acc, layer| deep_merge(acc, layer) }
    end

    def self.deep_merge(base, overrides)
      base.merge(overrides) do |_key, base_val, override_val|
        if base_val.is_a?(Hash) && override_val.is_a?(Hash)
          deep_merge(base_val, override_val)
        else
          override_val
        end
      end
    end
  end
end
