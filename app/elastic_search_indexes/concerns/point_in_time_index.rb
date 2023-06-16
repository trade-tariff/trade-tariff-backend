# Ensures all subsequent queries after initial dataset fetch also happen
# within TimeMachine

module PointInTimeIndex
  def dataset
    TimeMachine.now { super.actual }
  end

  def dataset_page(...)
    TimeMachine.now { super }
  end
end
