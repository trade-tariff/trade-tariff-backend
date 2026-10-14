# Generates and stores a run's three-word label (AI-1437), fire-and-forget, so the request
# that creates the run never waits on an OpenAI call. Enqueued at the end of
# EvaluationRun.start!, the same relationship GenerateGoldQueryItemWorker has to the record it
# labels -- a run whose label generation fails, or hasn't run yet, simply has label: nil and
# displays exactly as it does today.
class GenerateRunLabelWorker
  include Sidekiq::Worker

  # retry: 3 never fires for an OpenAI failure -- RunLabelGenerator already owns and exhausts
  # its own 3-attempt budget against OpenaiClient::RETRYABLE_ERRORS internally, returning nil
  # rather than raising, exactly like GenerateGoldQueryItemWorker/GoldQueryGenerator's
  # identical split does. It still matters for what's outside the generator's own rescue
  # scope: a transient Sequel::DatabaseError from the EvaluationRun[run_id] lookup above or
  # run.update(label:) inside the generator (AI-1437 review).
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
