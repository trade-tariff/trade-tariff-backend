module Api
  module V3
    class ExactSearchSerializer
      def self.call(presenter)
        {
          type: presenter.type,
          entry: presenter.entry,
        }
      end
    end

    class FuzzySearchSerializer
      def self.call(presenter)
        {
          type: presenter.type,
          goods_nomenclature_match: presenter.goods_nomenclature_match,
          reference_match: presenter.reference_match,
        }
      end
    end

    class NullSearchSerializer
      def self.call(presenter)
        {
          type: presenter.type,
          goods_nomenclature_match: presenter.goods_nomenclature_match,
          reference_match: presenter.reference_match,
        }
      end
    end
  end
end
