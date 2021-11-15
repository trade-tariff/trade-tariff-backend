class RingBuffer < Array
  attr_reader :max_size

  def initialize(max_size = 10)
    @max_size = max_size.to_i
  end

  def <<(el)
    shift if full?

    super
  end

  alias :push :<<

  def full?
    size == @max_size
  end
end
