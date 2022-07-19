FactoryBot.define do
  factory :guide do
    id {}
    title {}
    image {}
    url {}
    strapline {}

    trait :aircraft_parts do
      id { 1 }
      title { 'Aircraft parts' }
      image { 'aircraft.png' }
      url { 'https://www.gov.uk/guidance/classifying-aircraft-parts-and-accessories' }
      strapline { 'Get help to classify drones and aircraft parts for import and export.' }
    end
  end
end
