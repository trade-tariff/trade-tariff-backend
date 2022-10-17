module Beta
  module Search
    # Encapsulates a set of facet classifications for a given goods nomenclature
    #
    # These enable filtering on search results based on semantic categories (filter[animal_type]=swine).
    class FacetClassification
      attr_accessor :classifications

      class Declarable
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
                  # This means we skip assigning classifications for facets that have
                  # previously been assigned lower down the tree or description.
                  encountered_facet = classifications[facet].except(gn.goods_nomenclature_sid).any?
                  encountered_classification = classifications[facet][gn.goods_nomenclature_sid].present?

                  next if encountered_facet
                  next if encountered_classification

                  classifications[facet][gn.goods_nomenclature_sid] = classification
                end
              end
            end

            facet_classification = Beta::Search::FacetClassification.new

            facet_classification.classifications = classifications.transform_values do |goods_nomenclature_values|
              goods_nomenclature_values.values.first
            end

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

      class NonDeclarable
        class << self
          def build(_goods_nomenclature, _classifications = {})
            facet_classification = Beta::Search::FacetClassification.new

            facet_classification.classifications = {}

            facet_classification
          end
        end
      end
    end
  end
end
