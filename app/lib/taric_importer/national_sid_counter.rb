class TaricImporter
  # Seeds a single national SID per model from the DB once per import run, then hands out
  # decreasing values in-memory so that multiple SID-less records mapped ahead of the same
  # multi_insert flush don't read the same DB floor and collide on the same negative SID.
  class NationalSidCounter
    def initialize
      @next_values = {}
    end

    def next_for(klass)
      next_value = (@next_values[klass] ||= klass.next_national_sid)
      @next_values[klass] = next_value - 1
      next_value
    end
  end
end
