module EvaluationConfiguration
  # Deliberately minimal for AI-1066. AI-1065 owns sourcing the real
  # classification baseline from AdminConfiguration and replaces this
  # implementation; nothing else in EvaluationRun.start! needs to change
  # when that happens, since it only depends on .call returning a Hash.
  class BaselineProvider
    def self.call
      {}
    end
  end
end
