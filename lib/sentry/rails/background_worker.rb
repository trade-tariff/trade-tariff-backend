module Sentry
  module Rails
    class BackgroundWorker
      def _perform(&block)
        block.call
      end
    end
  end
end
