# Minimal hash-to-object presenter for serializer specs.
# Provides dot-notation access to nested hash data without inheriting from
# Hash or including Enumerable, so jsonapi-serializer treats it as a single
# record rather than a collection.
class HashPresenter
  def initialize(data)
    @data = data.transform_keys(&:to_s)
  end

  def method_missing(name, *_args)
    key = name.to_s
    return self.class.coerce(@data[key]) if @data.key?(key)

    super
  end

  def respond_to_missing?(name, include_private = false)
    @data.key?(name.to_s) || super
  end

  def [](key)
    self.class.coerce(@data[key.to_s])
  end

  def self.coerce(value)
    case value
    when Hash then new(value)
    when Array then value.map { |v| v.is_a?(Hash) ? new(v) : v }
    else value
    end
  end
end
