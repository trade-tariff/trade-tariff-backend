class NullObject
  def empty?
    true
  end

  def blank?
    true
  end

  def method_missing(*_args)
    nil
  end
end
