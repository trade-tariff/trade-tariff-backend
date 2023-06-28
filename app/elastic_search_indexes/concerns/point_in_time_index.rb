# Ensures all subsequent queries after initial dataset fetch also happen
# within TimeMachine

module PointInTimeIndex
  def dataset
    apply_constraints { super.actual }
  end

  def dataset_page(...)
    apply_constraints { super }
  end

  def apply_constraints(&block)
    TimeMachine.now(&block)
  end
end
