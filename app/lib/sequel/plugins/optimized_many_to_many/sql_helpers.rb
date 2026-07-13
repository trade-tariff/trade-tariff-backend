module Sequel
  module Plugins
    module OptimizedManyToMany
      module SqlHelpers
        def join_conditions(right_key, right_pk, join_table, target_table, db = Sequel::Model.db)
          join_table_name = extract_table_name(join_table)

          Array(right_key).zip(Array(right_pk)).map { |join_key, pk|
            left = db.literal(Sequel.qualify(join_table_name, join_key))
            right = db.literal(Sequel.qualify(target_table, pk))
            "#{left} = #{right}"
          }.join(' AND ')
        end

        def where_conditions(join_table, left_keys, db = Sequel::Model.db)
          join_table_name = extract_table_name(join_table)
          keys = Array(left_keys).map { |lk| Sequel.qualify(join_table_name, lk) }

          if keys.size == 1
            db.literal(keys.first)
          else
            "(#{keys.map { |k| db.literal(k) }.join(', ')})"
          end
        end

        def qualify_order(order, target_table, associated_class)
          return nil unless order

          qualified_order = Array(order).map do |o|
            if o.is_a?(Sequel::SQL::OrderedExpression)
              Sequel::SQL::OrderedExpression.new(
                Sequel.qualify(target_table, o.expression),
                o.descending,
              )
            else
              Sequel.qualify(target_table, o)
            end
          end

          qualified_order.map { |o| associated_class.dataset.literal(o) }.join(', ')
        end

        def table_ref(table, db = Sequel::Model.db)
          # Handles Symbol, AliasedExpression, QualifiedIdentifier, etc.
          db.literal(table)
        end

        def extract_table_name(table)
          if table.is_a?(Sequel::SQL::AliasedExpression)
            table.alias
          elsif table.is_a?(Sequel::SQL::QualifiedIdentifier)
            table.table
          else
            table
          end
        end
      end
    end
  end
end
