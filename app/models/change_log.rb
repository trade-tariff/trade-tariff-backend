class ChangeLog
  include Enumerable

  attr_reader :changes

  def initialize(changes = [])
    @changes = changes.map do |change_attributes|
      ChangeOld.new(change_attributes)
    end
  end

  def each(&block)
    @changes.each(&block)
  end
end
