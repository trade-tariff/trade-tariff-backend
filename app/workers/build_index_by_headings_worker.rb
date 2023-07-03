class BuildIndexByHeadingsWorker
  include Sidekiq::Worker

  sidekiq_options queue: :default, retry: false

  def perform(index_name)
    TimeMachine.now do
      Heading
        .actual
        .non_grouping
        .non_hidden
        .non_classifieds
        .select_map(:heading_short_code)
        .each do |heading_short_code|
          BuildIndexByHeadingWorker.perform_async(index_name, heading_short_code)
        end
    end
  end
end
