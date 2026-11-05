module EvaluationConfiguration
  # The reasoning effort a question model is actually sent. A level one model accepts another rejects,
  # so an effort that was chosen for a different model (the live setting, when a run only overrides the
  # question model) falls back to the model's most conservative level, and a model that does not reason
  # is sent none at all.
  #
  # InteractiveSearchService applies this when it makes the call. EvaluationRun.start! applies it to the
  # configuration it records, so what is recorded is what the search will use, and so the recorded
  # configuration (which the eval app sends back as overrides on every search) still passes validation.
  class ReasoningEffort
    def self.resolve(model:, configured:)
      levels = OpenaiClient::MODEL_CONFIGS.dig(model, :reasoning_levels) || []
      return nil if levels.empty?
      return configured if levels.include?(configured)

      levels.first
    end

    # The configuration with its reasoning_effort resolved for its question_model. The key is left out
    # when the model does not reason.
    def self.apply(configuration)
      effort = resolve(model: configuration['question_model'], configured: configuration['reasoning_effort'])
      resolved = configuration.except('reasoning_effort')

      effort ? resolved.merge('reasoning_effort' => effort) : resolved
    end
  end
end
