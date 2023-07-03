module BulkSearch
  class HitAncestorFinderService
    HEADING_DIGITS = 4

    def initialize(hit, number_of_digits)
      @hit = hit
      @number_of_digits = number_of_digits
    end

    def call
      candidate_ancestor, reason = find_result_in_ancestor

      if candidate_ancestor.blank?
        candidate_ancestor, reason = find_result_in_hit
      end

      if candidate_ancestor.blank?
        candidate_ancestor, reason = find_result_in_heading_ancestor
      end

      [candidate_ancestor, reason]
    end

    private

    attr_reader :hit, :number_of_digits

    def find_result_in_ancestor
      result = hit._source.ancestors.find do |ancestor|
        ancestor.short_code.length == number_of_digits
      end

      reason = :matching_digit_ancestor if result

      [result, reason]
    end

    def find_result_in_hit
      hit_digits = hit._source.short_code.length

      result = [number_of_digits, HEADING_DIGITS].include?(hit_digits) ? hit._source : nil

      reason = if result.present?
                 result.goods_nomenclature_class == 'Heading' ? :matching_declarable_heading : :matching_digit_commodity
               end

      [result, reason]
    end

    def find_result_in_heading_ancestor
      result = hit._source.ancestors.find do |ancestor|
        ancestor.short_code.length == HEADING_DIGITS
      end

      reason = :matching_heading_ancestor if result

      [result, reason]
    end
  end
end
