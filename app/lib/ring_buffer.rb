class RingBuffer < Array
  attr_reader :max_size

  def initialize(max_size = 10)
    super()
    @max_size = max_size.to_i
  end

  def <<(_)
    shift if full?

    super
  end

  alias_method :push, :<<

  def full?
    size == @max_size
  end
end
