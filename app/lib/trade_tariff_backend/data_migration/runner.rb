module TradeTariffBackend
  class DataMigration
    class Runner
      include BlockAccessor

      block_accessor :applicable, :apply

      alias :applicable? :applicable

      def initialize(migration, destination, &block)
        @migration = migration
        @destination = destination

        instance_eval &block if block_given?
      end

      def inspect
        vars = self.instance_variables
          .map { |v| "#{v}=#{instance_variable_get(v).inspect}" }.join(', ')
        "<#{self.class} #{@destination.to_s.capitalize}RunnerOn(#{@migration.class.to_s}): #{vars}>"
      end

      private

      def method_missing(method, *args, &block)
        @migration.send(method, *args, &block)
      end
    end
  end
end
