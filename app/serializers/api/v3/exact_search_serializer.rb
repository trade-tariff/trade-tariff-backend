module Api
  module V3
    class ExactSearchSerializer
      def self.call(presenter)
        {
          type: presenter.type,
          entry: presenter.entry,
        }
      end
    end
  end
end
