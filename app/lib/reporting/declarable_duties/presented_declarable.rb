module Reporting
  class DeclarableDuties
    class PresentedDeclarable < WrapDelegator
      def commodity__sid
        goods_nomenclature_sid
      end

      def commodity__code
        goods_nomenclature_item_id
      end

      def commodity__indent
        number_indents
      end

      def commodity__description
        description
      end
    end
  end
end
