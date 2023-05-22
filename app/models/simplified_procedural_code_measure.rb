class SimplifiedProceduralCodeMeasure < Sequel::Model
  def validity_start_date
    super&.to_date
  end

  def validity_end_date
    super&.to_date
  end

  dataset_module do
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
