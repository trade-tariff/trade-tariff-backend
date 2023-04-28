module Search
  class GoodsNomenclatureIndex < ::SearchIndex
    def dataset
      TimeMachine.now do
        Commodity # Filter out headings and chapters
          .actual
          .declarable # Avoid the majority of subheadings
          .non_hidden
      end
    end

    def eager_load_graph
      %i[
        chapter
        heading
        ns_ancestors
        ns_children
      ]
    end

    def definition
      if TradeTariffBackend.stemming_exclusion_reference_analyzer.present?
        # Stemming exclusions _must_ come before other filters
        base_definition[:settings][:index][:analysis][:analyzer][:english][:filter].unshift('english_stem_exclusions')
        base_definition[:settings][:index][:analysis][:filter][:english_stem_exclusions] = {
          type: 'stemmer_override',
          rules_path: TradeTariffBackend.stemming_exclusion_reference_analyzer,
        }
      end

      if TradeTariffBackend.synonym_reference_analyzer.present?
        # Synonyms _must_ come before the stemming exclusion filter otherwise
        # they will have a mixture of stemmed/unstemmed expanded terms
        base_definition[:settings][:index][:analysis][:analyzer][:english][:filter].unshift('synonym')
        base_definition[:settings][:index][:analysis][:filter][:synonym] = {
          type: 'synonym',
          synonyms_path: TradeTariffBackend.synonym_reference_analyzer,
        }
      end

      base_definition
    end

    private

    def base_definition
      @base_definition ||= {
        settings: {
          index: {
            analysis: {
              analyzer: {
                english_exact: {
                  tokenizer: 'standard',
                  filter: %w[lowercase],
                },
                english: {
                  tokenizer: 'standard',
                  filter: %w[
                    english_possessive_stemmer
                    lowercase
                    english_stop
                    english_stemmer
                  ],
                },
                english_shingle: {
                  tokenizer: 'standard',
                  filter: %w[
                    lowercase
                    shingle
                  ],
                },
              },
              filter: {
                english_stop: {
                  type: 'stop',
                  stopwords: '_english_',
                },
                english_stemmer: {
                  type: 'stemmer',
                  language: 'english',
                },
                english_possessive_stemmer: {
                  type: 'stemmer',
                  language: 'possessive_english',
                },
                shingle: {
                  type: 'shingle',
                  max_shingle_size: 3,
                },
              },
              char_filter: {
                standardise_quotes: {
                  type: 'mapping',
                  mappings: [
                    '\\u0091=>\\u0027',
                    '\\u0092=>\\u0027',
                    '\\u2018=>\\u0027',
                    '\\u2019=>\\u0027',
                    '\\u201B=>\\u0027',
                  ],
                },
              },
            },
          },
        },
        mappings: {
          properties: {
            id: { type: 'text' },
            goods_nomenclature_class: { type: 'keyword' },
            goods_nomenclature_item_id: { analyzer: 'english', type: 'text' },
            producline_suffix: { type: 'keyword' },
            chapter_id: { type: 'keyword' },
            heading_id: { type: 'keyword' },
            search_references: { analyzer: 'english', type: 'text' },
            search_intercept_terms: { analyzer: 'english', type: 'text' },
            description_indexed: { analyzer: 'english', type: 'text' },
            ancestor_1_description_indexed: { analyzer: 'english', type: 'text' },
            ancestor_2_description_indexed: { analyzer: 'english', type: 'text' },
            ancestor_3_description_indexed: { analyzer: 'english', type: 'text' },
            ancestor_4_description_indexed: { analyzer: 'english', type: 'text' },
            ancestor_5_description_indexed: { analyzer: 'english', type: 'text' },
            ancestor_6_description_indexed: { analyzer: 'english', type: 'text' },
            ancestor_7_description_indexed: { analyzer: 'english', type: 'text' },
            ancestor_8_description_indexed: { analyzer: 'english', type: 'text' },
            ancestor_9_description_indexed: { analyzer: 'english', type: 'text' },
            ancestor_10_description_indexed: { analyzer: 'english', type: 'text' },
            ancestor_11_description_indexed: { analyzer: 'english', type: 'text' },
            ancestor_12_description_indexed: { analyzer: 'english', type: 'text' },
            ancestor_13_description_indexed: { analyzer: 'english', type: 'text' },
            description_indexed_shingled: { analyzer: 'english_shingle', type: 'text' },
            ancestor_1_description_indexed_shingled: { analyzer: 'english_shingle', type: 'text' },
            ancestor_2_description_indexed_shingled: { analyzer: 'english_shingle', type: 'text' },
            ancestor_3_description_indexed_shingled: { analyzer: 'english_shingle', type: 'text' },
            ancestor_4_description_indexed_shingled: { analyzer: 'english_shingle', type: 'text' },
            ancestor_5_description_indexed_shingled: { analyzer: 'english_shingle', type: 'text' },
            ancestor_6_description_indexed_shingled: { analyzer: 'english_shingle', type: 'text' },
            ancestor_7_description_indexed_shingled: { analyzer: 'english_shingle', type: 'text' },
            ancestor_8_description_indexed_shingled: { analyzer: 'english_shingle', type: 'text' },
            ancestor_9_description_indexed_shingled: { analyzer: 'english_shingle', type: 'text' },
            ancestor_10_description_indexed_shingled: { analyzer: 'english_shingle', type: 'text' },
            ancestor_11_description_indexed_shingled: { analyzer: 'english_shingle', type: 'text' },
            ancestor_12_description_indexed_shingled: { analyzer: 'english_shingle', type: 'text' },
            ancestor_13_description_indexed_shingled: { analyzer: 'english_shingle', type: 'text' },
            filter_alcohol_volume: { type: 'keyword' },
            filter_animal_product_state: { type: 'keyword' },
            filter_animal_type: { type: 'keyword' },
            filter_art_form: { type: 'keyword' },
            filter_battery_charge: { type: 'keyword' },
            filter_battery_grade: { type: 'keyword' },
            filter_battery_type: { type: 'keyword' },
            filter_beverage_type: { type: 'keyword' },
            filter_bone_state: { type: 'keyword' },
            filter_bovine_age_gender: { type: 'keyword' },
            filter_bread_type: { type: 'keyword' },
            filter_brix_value: { type: 'keyword' },
            filter_cable_type: { type: 'keyword' },
            filter_car_capacity: { type: 'keyword' },
            filter_car_type: { type: 'keyword' },
            filter_cereal_state: { type: 'keyword' },
            filter_cheese_type: { type: 'keyword' },
            filter_clothing_fabrication: { type: 'keyword' },
            filter_clothing_gender: { type: 'keyword' },
            filter_cocoa_state: { type: 'keyword' },
            filter_coffee_state: { type: 'keyword' },
            filter_computer_type: { type: 'keyword' },
            filter_dairy_form: { type: 'keyword' },
            filter_egg_purpose: { type: 'keyword' },
            filter_egg_shell_state: { type: 'keyword' },
            filter_electrical_output: { type: 'keyword' },
            filter_electricity_type: { type: 'keyword' },
            filter_entity: { type: 'keyword' },
            filter_fat_content: { type: 'keyword' },
            filter_fish_classification: { type: 'keyword' },
            filter_fish_preparation: { type: 'keyword' },
            filter_flour_source: { type: 'keyword' },
            filter_fruit_spirit: { type: 'keyword' },
            filter_fruit_vegetable_state: { type: 'keyword' },
            filter_fruit_vegetable_type: { type: 'keyword' },
            filter_garment_material: { type: 'keyword' },
            filter_garment_type: { type: 'keyword' },
            filter_glass_form: { type: 'keyword' },
            filter_glass_purpose: { type: 'keyword' },
            filter_height: { type: 'keyword' },
            filter_herb_spice_state: { type: 'keyword' },
            filter_ingredient: { type: 'keyword' },
            filter_jam_sugar_content: { type: 'keyword' },
            filter_jewellery_type: { type: 'keyword' },
            filter_length: { type: 'keyword' },
            filter_margarine_state: { type: 'keyword' },
            filter_material: { type: 'keyword' },
            filter_metal_type: { type: 'keyword' },
            filter_metal_usage: { type: 'keyword' },
            filter_monitor_connectivity: { type: 'keyword' },
            filter_monitor_type: { type: 'keyword' },
            filter_mounting: { type: 'keyword' },
            filter_new_used: { type: 'keyword' },
            filter_nut_state: { type: 'keyword' },
            filter_oil_fat_source: { type: 'keyword' },
            filter_pasta_state: { type: 'keyword' },
            filter_plant_state: { type: 'keyword' },
            filter_precious_stone: { type: 'keyword' },
            filter_product_age: { type: 'keyword' },
            filter_pump_type: { type: 'keyword' },
            filter_purpose: { type: 'keyword' },
            filter_sugar_state: { type: 'keyword' },
            filter_template: { type: 'keyword' },
            filter_tobacco_type: { type: 'keyword' },
            filter_vacuum_type: { type: 'keyword' },
            filter_weight: { type: 'keyword' },
            filter_wine_origin: { type: 'keyword' },
            filter_wine_type: { type: 'keyword' },
            filter_yeast_state: { type: 'keyword' },
            declarable: { type: 'keyword' },
            description: { enabled: false },
            ancestors: { enabled: false },
            ancestor_ids: { enabled: false },
            validity_start_date: { enabled: false },
            validity_end_date: { enabled: false },
            guides: { enabled: false },
            guide_ids: { enabled: false },
          },
        },
      }
    end
  end
end
