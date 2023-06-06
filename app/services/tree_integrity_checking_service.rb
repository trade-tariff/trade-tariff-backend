class TreeIntegrityCheckingService
  attr_reader :failures

  def initialize
    @failures = []
  end

  def check!
    Chapter.actual.all.each do |chapter|
      chapter.ns_descendants.each do |descendant|
        if (descendant.ns_children.empty? && descendant.ns_descendants.any?) ||
            descendant.ns_parent.nil?
          @failures << descendant.goods_nomenclature_sid
        end
      end
    end

    @failures.empty?
  end
end
