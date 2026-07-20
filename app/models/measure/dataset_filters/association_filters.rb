class Measure
  module DatasetFilters
    module AssociationFilters
      def with_additional_code_sid(additional_code_sid)
        return self if additional_code_sid.blank?

        where(additional_code_sid:)
      end

      def with_additional_code_type(additional_code_type_id)
        return self if additional_code_type_id.blank?

        where(additional_code_type_id:)
      end

      def with_additional_code_id(additional_code_id)
        return self if additional_code_id.blank?

        where(additional_code_id:)
      end

      def join_measure_conditions
        association_right_join(:measure_conditions)
          .where(Sequel.~(measures__measure_sid: nil))
      end

      def with_certificate_type_code(type)
        return self if type.blank?

        where(measure_conditions__certificate_type_code: type)
      end

      def with_certificate_code(code)
        return self if code.blank?

        where(measure_conditions__certificate_code: code)
      end

      def with_certificate_types_and_codes(certificate_types_and_codes)
        combine_pair_conditions(
          certificate_types_and_codes,
          :measure_conditions__certificate_type_code,
          :measure_conditions__certificate_code,
        )
      end

      def join_footnotes
        association_right_join(:footnotes)
          .exclude(measures__measure_sid: nil)
      end

      def with_footnote_type_id(footnote_type_id)
        return self if footnote_type_id.blank?

        where(footnotes__footnote_type_id: footnote_type_id)
      end

      def with_footnote_id(footnote_id)
        return self if footnote_id.blank?

        where(footnotes__footnote_id: footnote_id)
      end

      def with_footnote_types_and_ids(footnote_types_and_ids)
        combine_pair_conditions(
          footnote_types_and_ids,
          :footnotes__footnote_type_id,
          :footnotes__footnote_id,
        )
      end

    private

      # Builds an OR-combined Sequel condition from a collection of [col_a, col_b]
      # value pairs and applies it as a WHERE clause. Returns the dataset unchanged
      # if the pairs collection is empty.
      def combine_pair_conditions(pairs, col_a, col_b)
        return self if pairs.none?

        conditions = pairs.map { |a, b| Sequel.expr(col_a => a) & Sequel.expr(col_b => b) }
        where(conditions.reduce(:|))
      end
    end
  end
end
