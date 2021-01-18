FactoryBot.define do
  factory :measure_excluded_geographical_area do |f|
    f.measure_sid { generate(:measure_sid) }
    f.geographical_area_sid { generate(:geographical_area_sid) }
    f.excluded_geographical_area { Forgery(:basic).text(exactly: 2) }

    # mandatory valid associations
    f.measure { create :measure, measure_sid: measure_sid }
    f.geographical_area do
      create :geographical_area,
             geographical_area_sid: geographical_area_sid,
             geographical_area_id: excluded_geographical_area
    end
  end
end
