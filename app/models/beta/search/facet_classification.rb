module Beta
  module Search
    # Encapsulates a set a facet classifications for a given goods nomenclature
    #
    # These will either be single (e.g. for a specific commodity) => animal_type: [swine]
    # Or multiple (e.g. for a heading) => animal_type: [swine, horses, etc]
    #
    # These enable filtering on search results based on semantic categories.
    class FacetClassification
      attr_accessor :classifications

      class << self
        def build(goods_nomenclature)
          classifications = {}
          goods_nomenclatures = goods_nomenclature.ancestors << goods_nomenclature
          applicable_facet_classifiers = heading_facet_mappings[goods_nomenclature.heading.short_code]

          classifiables_for(goods_nomenclatures).each do |classifiable|
            matching_facet_classifications = word_classifications[classifiable] || {}

            matching_facet_classifications.slice(*applicable_facet_classifiers).each do |facet, classification|
              if classifications[facet].blank?
                classifications[facet] = classification
              end
            end
          end

          facet_classification = new

          facet_classification.classifications = classifications

          facet_classification
        end

        def classifiables_for(goods_nomenclatures)
          all_classifiables = []

          all_classifiables.concat(phrases_for(goods_nomenclatures))
          all_classifiables.concat(tokens_for(goods_nomenclatures))

          all_classifiables
        end

        def phrases_for(goods_nomenclatures)
          Api::Beta::GoodsNomenclaturePhraseTokenGeneratorService.new(goods_nomenclatures).call
        end

        def tokens_for(goods_nomenclatures)
          tokens = Api::Beta::GoodsNomenclatureTokenGeneratorService.new(goods_nomenclatures).call

          tokens.pluck(:analysed_token)
        end

        def word_classifications
          TradeTariffBackend.search_facet_classifier_configuration.word_classifications
        end

        def heading_facet_mappings
          TradeTariffBackend.search_facet_classifier_configuration.heading_facet_mappings
        end
      end
    end
  end
end
