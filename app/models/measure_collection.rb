class MeasureCollection
  def initialize(measures)
    @measures = measures
  end

  def filter
    if TradeTariffBackend.xi?
      @measures.reject(&:excise?)
    else
      @measures
    end
  end
end
