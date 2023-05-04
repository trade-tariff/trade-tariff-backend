class WrapDelegator < SimpleDelegator
  class << self
    def wrap(records, ...)
      records.map do |record|
        new(record, ...)
      end
    end
  end
end
