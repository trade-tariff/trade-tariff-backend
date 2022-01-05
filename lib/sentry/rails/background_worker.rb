module Sentry
  class BackgroundWorker
    def _perform(&block)
      block.call
    end
  end
end
