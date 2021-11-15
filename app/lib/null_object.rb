class NullObject
  def empty?
    true
  end

  def blank?
    true
  end

  def method_missing(*args, &block)
    nil
  end
end
