module SequelQueryCount
  def log_process_action(payload)
    messages = super
    messages << sprintf('Queries: %s',
                        ::SequelRails::Railties::LogSubscriber.count)
    messages
  end
end

ActionController::Base.extend(SequelQueryCount)
