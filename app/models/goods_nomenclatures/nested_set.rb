# Full explanation in docs/goods-nomenclature-nested-set.md
# For usage - see the 'Querying in Ruby` section in the above document

module GoodsNomenclatures
  module NestedSet
    extend ActiveSupport::Concern

    include AncestorAssociations
    include DescendantAssociations
    include MeasureAssociations
    include Populators
    include Predicates

    class DateNotSet < RuntimeError
      def initialize
        super 'TimeMachine date is not set, code should be inside TimeMachine.now {}'
      end
    end
  end
end
