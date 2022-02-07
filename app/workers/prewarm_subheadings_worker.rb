class PrewarmSubheadingsWorker
  CACHE_CHILDREN_COUNT = 10

  include Sidekiq::Worker

  sidekiq_options queue: :default, retry: true

  def perform
    TimeMachine.at(actual_date) do
      # Enable efficient enumeration of non-declarables
      ExpensiveHeadingCommodityContextService.new.call do
        applicable_subheadings.each do |subheading|
          CachedSubheadingService.new(subheading, actual_date.iso8601).call
        end
      end
    end
  end

  private

  def applicable_subheadings
    Subheading.actual.all.select do |subheading|
      # Only prewarm the most expensive subheadings
      subheading.children.count > CACHE_CHILDREN_COUNT
    end
  end

  def actual_date
    @actual_date ||= Time.zone.today
  end
end
