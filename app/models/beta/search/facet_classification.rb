module Beta
  module Search
    # Encapsulates a set of facet classifications for a given goods nomenclature
    #
    # These enable filtering on search results based on semantic categories (filter[animal_type]=swine).
    class FacetClassification
      attr_accessor :classifications

      class << self
        def build(goods_nomenclature, classifications = {})
          applicable_facet_classifiers = heading_facet_mappings[goods_nomenclature.heading.short_code]

          goods_nomenclature.classifiable_goods_nomenclatures.each do |gn|
            tokens_for(gn).each do |token|
              matching_facet_classifications = word_classifications[token] || {}

              matching_facet_classifications.slice(*applicable_facet_classifiers).each do |facet, classification|
                classifications[facet] ||= {}

                # We always want the most precise classifications
                #
                # In practice this means we bail extending classifications if the lowest goods_nomenclature
                # node in the tree has found any for the given facet category
                next if classifications[facet].except(gn.goods_nomenclature_sid).any?

                classifications[facet][gn.goods_nomenclature_sid] ||= Set.new
                classifications[facet][gn.goods_nomenclature_sid] << classification
              end
            end
          end

          # Facet category classifications can only belong to one goods_nomenclature
          classifications = classifications.transform_values(&:values).transform_values(&:first)

          facet_classification = new

          facet_classification.classifications = classifications

          facet_classification
        end

        def empty
          facet_classification = new

          facet_classification.classifications = {}

          facet_classification
        end

        def tokens_for(goods_nomenclature)
          Api::Beta::GoodsNomenclatureTokenGeneratorService.new(goods_nomenclature).call
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
