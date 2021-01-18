class LoopingSequence
  attr_reader :value

  def self.lower_a_to_upper_z
    new(Set[*('a'..'z'), *('A'..'Z')])
  end

  def initialize(seed)
    self.enumerator = Set.new(seed).each
    self.next
  end

  def next
    self.value = next_value
    self
  end

  private

  attr_accessor :enumerator
  attr_writer :value

  def next_value
    enumerator.next
  rescue StopIteration
    enumerator.rewind
    retry
  end
end
