module Sentry
  module Rails
    class BackgroundWorker
      def _perform
        yield
      end
    end
  end
end
