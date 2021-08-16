module TradeTariffBackend
  class DataMigration
    attr_accessor :name, :desc

    def initialize(&block)
      instance_eval(&block) if block_given?
    end

    # rubocop:disable Lint/DuplicateMethods
    def name(name = '')
      if name.present?
        @name = name
      else
        @name
      end
    end

    def desc(desc = '')
      if desc.present?
        @desc = desc
      else
        @desc
      end
    end
    # rubocop:enable Lint/DuplicateMethods

    # If called with block set up migration runner
    # Otherwise return the preset runner
    def down(&block)
      if block_given?
        define_down_runner(&block)
      else
        @down_runner || NullRunner.new(self, :up)
      end
    end

    # If called with block set down migration runner
    # Otherwise return the preset runner
    def up(&block)
      if block_given?
        define_up_runner(&block)
      else
        @up_runner || NullRunner.new(self, :up)
      end
    end

    def can_rollup?
      up.applicable? || false
    end

    def can_rolldown?
      down.applicable? || false
    end

    def inspect
      "<#{self.class}: #{@name}>"
    end

    private

    def define_up_runner(&block)
      raise ArgumentError, '#define_up_runner expects block to be passed in' unless block_given?

      @up_runner = Runner.new(self, :up, &block)
    end

    def define_down_runner(&block)
      raise ArgumentError, '#define_down_runner expects block to be passed in' unless block_given?

      @down_runner = Runner.new(self, :down, &block)
    end
  end
end
