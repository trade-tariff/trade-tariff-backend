# Generates and stores a run's three-word label (AI-1437), fire-and-forget, so the request
# that creates the run never waits on an OpenAI call. Enqueued at the end of
# EvaluationRun.start!, the same relationship GenerateGoldQueryItemWorker has to the record it
# labels -- a run whose label generation fails, or hasn't run yet, simply has label: nil and
# displays exactly as it does today.
class GenerateRunLabelWorker
  include Sidekiq::Worker

  sidekiq_options queue: :within_1_hour, retry: 3

  # overrides is the run's own launch-time configuration snapshot, resolved once by
  # EvaluationRun.start! and passed through as a job argument rather than re-read from
  # run.evaluation_experiment here -- that association is live, and an experiment's
  # configuration_overrides can be edited after this job was enqueued but before Sidekiq
  # actually runs it (AI-1437 review).
  def perform(run_id, overrides)
    run = EvaluationRun[run_id]
    return unless run # The run was deleted while this job waited in the queue.

    Evaluation::RunLabelGenerator.call(run, overrides)
  end
end
