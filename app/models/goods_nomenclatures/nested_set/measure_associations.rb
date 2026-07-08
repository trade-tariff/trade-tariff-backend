module GoodsNomenclatures
  module NestedSet
    module MeasureAssociations
      extend ActiveSupport::Concern

      included do
        one_to_many :measures,
                    primary_key: :goods_nomenclature_sid,
                    key: :goods_nomenclature_sid,
                    class_name: '::Measure',
                    read_only: true do |ds|
          ds.with_actual(Measure)
            .dedupe_similar
            .with_regulation_dates_query
            .without_excluded_types
        end

        one_to_many :overview_measures,
                    primary_key: :goods_nomenclature_sid,
                    key: :goods_nomenclature_sid,
                    class_name: '::Measure',
                    read_only: true do |ds|
          ds.with_actual(Measure)
            .dedupe_similar
            .with_regulation_dates_query
            .without_excluded_types
            .overview
        end

        def_column_accessor :leaf

        dataset_module do
          def with_leaf_column
            association_inner_join(tree_node: proc { |ds| ds.join_child_sids })
              .select_all(:goods_nomenclatures)
              .select_append(:tree_node__number_indents, :tree_node__depth)
              .select_append(Sequel.as({ tree_node__child_sid: nil }, :leaf))
              .distinct
          end

          def declarable
            with_leaf_column
              .non_grouping
              .where(tree_node__child_sid: nil)
          end
        end
      end
    end
  end
end
