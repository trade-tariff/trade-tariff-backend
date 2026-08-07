module VatGuidance
  class CommodityContextCatalog
    FOOD_GUIDE_KEY = 'vat-notice-701-14'.freeze
    AIRCRAFT_GUIDE_KEY = 'vat-notice-744c'.freeze

    CONTEXTS = [
      {
        'chapter' => '20',
        'chapter_label' => 'Prepared food',
        'commodity_code' => '2005202000',
        'label' => 'Packaged potato crisps',
        'evidence' => [
          { 'guide_key' => FOOD_GUIDE_KEY, 'section_key' => 'food-supplied-in-the-course-of-catering' },
          { 'guide_key' => FOOD_GUIDE_KEY, 'section_key' => 'savoury-snacks' },
        ],
      },
      {
        'chapter' => '20',
        'chapter_label' => 'Prepared food',
        'commodity_code' => '2008939120',
        'label' => 'Sweetened dried cranberries',
        'evidence' => [
          { 'guide_key' => FOOD_GUIDE_KEY, 'section_key' => 'food-supplied-in-the-course-of-catering' },
          { 'guide_key' => FOOD_GUIDE_KEY, 'section_key' => 'food-not-supplied-in-the-course-of-catering' },
          { 'guide_key' => FOOD_GUIDE_KEY, 'section_key' => 'confectionery' },
          { 'guide_key' => FOOD_GUIDE_KEY, 'section_key' => 'products-used-in-commercial-food-manufacture' },
        ],
      },
      {
        'chapter' => '20',
        'chapter_label' => 'Prepared food',
        'commodity_code' => '2008979890',
        'label' => 'Prepared fruit/plant mixtures',
        'evidence' => [
          { 'guide_key' => FOOD_GUIDE_KEY, 'section_key' => 'what-does-food-of-a-kind-used-for-human-consumption-mean' },
          { 'guide_key' => FOOD_GUIDE_KEY, 'section_key' => 'food-supplied-in-the-course-of-catering' },
          { 'guide_key' => FOOD_GUIDE_KEY, 'section_key' => 'food-not-supplied-in-the-course-of-catering' },
          { 'guide_key' => FOOD_GUIDE_KEY, 'section_key' => 'basic-foodstuffs' },
          { 'guide_key' => FOOD_GUIDE_KEY, 'section_key' => 'confectionery' },
          { 'guide_key' => FOOD_GUIDE_KEY, 'section_key' => 'ingredients-for-home-beer-and-wine-making' },
        ],
      },
      {
        'chapter' => '84',
        'chapter_label' => 'Aviation and machinery',
        'commodity_code' => '8407100010',
        'label' => 'Civil-aircraft engines',
        'evidence' => [
          { 'guide_key' => AIRCRAFT_GUIDE_KEY, 'section_key' => 'qualifying-aircraft' },
          { 'guide_key' => AIRCRAFT_GUIDE_KEY, 'section_key' => 'qualifying-aircraft-on-international-routes' },
          { 'guide_key' => AIRCRAFT_GUIDE_KEY, 'section_key' => 'conditions-for-zero-rating' },
        ],
      },
      {
        'chapter' => '84',
        'chapter_label' => 'Aviation and machinery',
        'commodity_code' => '8409100090',
        'label' => 'Aircraft-engine parts',
        'evidence' => [
          { 'guide_key' => AIRCRAFT_GUIDE_KEY, 'section_key' => 'qualifying-aircraft' },
          { 'guide_key' => AIRCRAFT_GUIDE_KEY, 'section_key' => 'qualifying-aircraft-on-international-routes' },
          { 'guide_key' => AIRCRAFT_GUIDE_KEY, 'section_key' => 'conditions-for-zero-rating' },
        ],
      },
      {
        'chapter' => '84',
        'chapter_label' => 'Aviation and machinery',
        'commodity_code' => '8424100011',
        'label' => 'Cylinders classified under civil-aircraft fire extinguishers',
        'evidence' => [
          { 'guide_key' => AIRCRAFT_GUIDE_KEY, 'section_key' => 'qualifying-aircraft' },
          { 'guide_key' => AIRCRAFT_GUIDE_KEY, 'section_key' => 'qualifying-aircraft-on-international-routes' },
          { 'guide_key' => AIRCRAFT_GUIDE_KEY, 'section_key' => 'conditions-for-zero-rating' },
          { 'guide_key' => AIRCRAFT_GUIDE_KEY, 'section_key' => 'parts-and-equipment-that-qualify-for-zero-rating' },
        ],
      },
    ].freeze

    def self.all
      CONTEXTS.deep_dup
    end
  end
end
