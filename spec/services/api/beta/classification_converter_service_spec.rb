RSpec.describe Api::Beta::ClassificationConverterService do
  describe '#call' do
    subject(:call) { described_class.new.call }

    let(:expected_facet_classifiers) do
      %w[
        alcohol_volume
        animal_product_state
        animal_type
        art_form
        battery_charge
        battery_grade
        battery_type
        beverage_type
        bone_state
        bovine_age_gender
        bread_type
        brix_value
        cable_type
        car_capacity
        car_type
        cereal_state
        cheese_type
        clothing_fabrication
        clothing_gender
        cocoa_state
        coffee_state
        computer_type
        dairy_form
        egg_purpose
        egg_shell_state
        electrical_output
        electricity_type
        entity
        fat_content
        fish_classification
        fish_preparation
        flour_source
        fruit_spirit
        fruit_vegetable_state
        fruit_vegetable_type
        garment_material
        garment_type
        glass_form
        glass_purpose
        height
        herb_spice_state
        ingredient
        jam_sugar_content
        jewellery_type
        length
        margarine_state
        material
        metal_type
        metal_usage
        monitor_connectivity
        monitor_type
        mounting
        new_used
        nut_state
        oil_fat_source
        pasta_state
        plant_state
        precious_stone
        product_age
        pump_type
        purpose
        sugar_state
        template
        tobacco_type
        vacuum_type
        weight
        wine_origin
        wine_type
        yeast_state
      ]
    end

    it { is_expected.to be_a(::Beta::Search::SearchFacetClassifierConfiguration) }

    it { expect(call.word_phrases).to include('2 litres or less') }
    it { expect(call.word_classifications['asses']).to eq('animal_type' => 'equine animals') }
    it { expect(call.word_classifications['ass']).to eq('animal_type' => 'equine animals') }
    it { expect(call.facet_classifiers.keys).to eq(expected_facet_classifiers) }
  end
end
