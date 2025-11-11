# frozen_string_literal: true

Sequel.migration do
  up do
    if TradeTariffBackend.xi?
      GreenLanes::CategoryAssessment.where(measure_type_id: '566').delete
    end
  end

  down do
    # No-op
  end
end
