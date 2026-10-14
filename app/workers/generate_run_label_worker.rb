# Generates and stores a run's three-word label (AI-1437), fire-and-forget, so the request
# that creates the run never waits on an OpenAI call. Enqueued at the end of
# EvaluationRun.start!, the same relationship GenerateGoldQueryItemWorker has to the record it
# labels -- a run whose label generation fails, or hasn't run yet, simply has label: nil and
# displays exactly as it does today.
class GenerateRunLabelWorker
  include Sidekiq::Worker

  sidekiq_options queue: :within_1_hour, retry: 3

  def perform(run_id)
    run = EvaluationRun[run_id]
    return unless run # The run was deleted while this job waited in the queue.

    Evaluation::RunLabelGenerator.call(run)
  end
end
