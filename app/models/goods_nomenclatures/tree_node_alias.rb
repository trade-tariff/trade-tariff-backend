module GoodsNomenclatures
  class TreeNodeAlias
    attr_reader :table

    def initialize(table)
      @table = table
    end

    def position
      @position ||= Sequel.qualify(@table, :position)
    end

    def depth
      @depth ||= Sequel.qualify(@table, :depth)
    end
  end
end
