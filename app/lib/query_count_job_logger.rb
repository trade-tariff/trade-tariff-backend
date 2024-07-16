require 'sidekiq/component'
require 'sidekiq/job_logger'

class QueryCountJobLogger < ::Sidekiq::JobLogger
  def call(item, queue)
    super do
      reset_query_count

      yield

      Sidekiq::Context.add(:queries, query_count)
    end
  end

  private

  def query_count
    ::SequelRails::Railties::LogSubscriber.count
  end

  def reset_query_count
    ::SequelRails::Railties::LogSubscriber.reset_count
  end
end
