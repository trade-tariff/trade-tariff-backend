# frozen_string_literal: true

Sequel.migration do
  up do
    
    tariff_stop_press_collection = News::Collection.where(id: 3)
    tariff_stop_press_collection.update(description: '')
    
  end

  down do
    original_description = <<~DESC
      ## More information

      To stop getting the Tariff stop press notices, or to add recipients to
      the distribution list, email: [tariff.management@hmrc.gov.uk](mailto:tariff.management@hmrc.gov.uk).
    DESC

    tariff_stop_press_collection = News::Collection.where(id: 3)
    tariff_stop_press_collection.update(description: original_description)
  end
end
