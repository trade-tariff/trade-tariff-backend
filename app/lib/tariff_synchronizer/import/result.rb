module TariffSynchronizer
  module Import
    class Result < Hash
      def initialize(operations:, total_count:, total_duration:)
        super()
        merge!(operations:, total_count:, total_duration:)
      end
    end
  end
end
