class SimplifiedProceduralCodeMeasure < Sequel::Model
  def validity_start_date
    super&.to_date
  end

  def validity_end_date
    super&.to_date
  end

  dataset_module do
    def with_filter(filters)
      return self if filters.empty?

      from_date = filters[:from_date]
      to_date = filters[:to_date]
      simplified_procedural_code = filters[:simplified_procedural_code]

      by_spv(simplified_procedural_code)
        .from_date(from_date)
        .to_date(to_date)
        .order(Sequel.desc(:validity_start_date))
        .all
    end

    def by_spv(simplified_procedural_code)
      return self if simplified_procedural_code.blank?

      where(simplified_procedural_code:)
    end

    # Return measures that are valid on or after this date
    def from_date(date)
      return self if date.blank?

      date = date.to_date.beginning_of_day

      where(validity_start_date: date..)
    end

    # Return measures that are valid on or before this date
    def to_date(date)
      return self if date.blank?

      date = date.to_date.end_of_day

      where(validity_end_date: ..date)
    end
  end
end
