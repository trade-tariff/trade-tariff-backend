class GenerateMaterializedPathsWorker
  include Sidekiq::Worker

  sidekiq_options retry: false

  def perform
    TimeMachine.now do
      Chapter.dataset.actual.each do |chapter|
        MaterializedPathUpdaterService.new(chapter).call
      end
    end
  end
end
