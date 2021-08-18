class Object
  def tap!
    result = yield(self)
    result.nil? ? self : result
  end
end
