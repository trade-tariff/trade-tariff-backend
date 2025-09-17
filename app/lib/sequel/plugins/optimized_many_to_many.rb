# lib/sequel/plugins/optimized_many_to_many.rb
module Sequel
  module Plugins
    module OptimizedManyToMany
      module_function

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

      module ClassMethods
        def many_to_many(name, opts = OPTS, &block)
          opts = opts.dup
          model_class = self
          assoc_name = name.to_sym

          # Full optimization: dataset + eager loader
          unless opts[:use_optimized] == false || opts[:use_optimized_dataset] == false || opts.key?(:dataset) || block
            opts[:dataset] = pg_optimized_many_to_many_dataset_proc
          end

          # Eager loader optimization can be toggled independently
          unless opts[:use_optimized] == false || opts.key?(:eager_loader)
            opts[:eager_loader] = pg_optimized_many_to_many_eager_loader_proc(assoc_name, model_class)
          end

          super(name, opts, &block)
        end

        def pg_optimized_many_to_many_dataset_proc
          proc do |r|
            associated_class = r.associated_class
            left_pks = Array(r[:left_primary_key])
            join_table = r[:join_table]
            left_keys = Array(r[:left_key])
            right_keys = Array(r[:right_key])
            right_pks = Array(r[:right_primary_key])
            order = r[:order]
            target_table = associated_class.table_name

            join_conditions = OptimizedManyToMany.join_conditions(right_keys, right_pks, join_table, target_table)
            order_sql = OptimizedManyToMany.qualify_order(order, target_table, associated_class)
            where_sql = OptimizedManyToMany.where_conditions(join_table, left_keys)

            sql = <<~SQL.strip
              SELECT #{target_table}.*
              FROM #{target_table}
              JOIN #{OptimizedManyToMany.table_ref(join_table)} ON #{join_conditions}
              WHERE #{where_sql} = #{left_pks.size == 1 ? '?' : "(#{(['?'] * left_pks.size).join(', ')})"}
              #{order_sql ? "ORDER BY #{order_sql}" : ''}
            SQL

            # Build bind arguments (support composite keys)
            bind_args = Array(left_pks).map { |pk| send(pk) }
            associated_class.with_sql(sql, *bind_args)
          end
        end

        def pg_optimized_many_to_many_eager_loader_proc(assoc_name, model_class)
          proc do |eo|
            refl = model_class.association_reflection(assoc_name)
            associated_class = refl.associated_class
            left_pks = Array(refl[:left_primary_key])
            ids = eo[:id_map].keys
            join_table = refl[:join_table]
            left_keys = Array(refl[:left_key])
            right_keys = Array(refl[:right_key])
            target_table = associated_class.table_name
            right_pks = Array(refl[:right_primary_key])
            order = refl[:order]
            cte_name = "filter_ids"

            # Build join conditions for right-hand side
            join_conditions = OptimizedManyToMany.join_conditions(right_keys, right_pks, join_table, target_table)
            order_sql = OptimizedManyToMany.qualify_order(order, target_table, associated_class)

            # Build the CTE for composite keys
            cte_columns = left_pks.map(&:to_s).join(", ")
            unnest_args = left_pks.each_with_index.map { |_, i| "unnest(?)" }.join(", ")
            fk_selects = left_keys.each_with_index.map do |lk, i|
              "#{join_table}.#{lk} AS x_fk_#{lk}"
            end.join(", ")

            sql = <<~SQL.strip
              WITH #{cte_name} (#{cte_columns}) AS (
                SELECT #{unnest_args}
              )
              SELECT #{target_table}.*, #{fk_selects}
              FROM #{target_table}
              JOIN #{OptimizedManyToMany.table_ref(join_table)} ON #{join_conditions}
              JOIN #{cte_name} fm ON #{left_keys.zip(left_pks).map { |lk, pk| "fm.#{pk} = #{join_table}.#{lk}" }.join(" AND ")}
              #{order_sql ? "ORDER BY #{order_sql}" : ''}
            SQL

            # Build bind arguments for unnest
            bind_args = left_pks.map.with_index do |pk, i|
              Sequel.pg_array(ids.map { |k| Array(k)[i] })
            end

            dataset = associated_class.with_sql(sql, *bind_args)
            records = dataset.all

            # Load nested associations if requested
            if eo[:associations]
              associated_class.eager(eo[:associations])
            end

            # Group by composite key (tuples)
            grouped = Hash.new { |h, k| h[k] = [] }
            records.each do |rec|
              key_values = left_keys.map { |lk| rec.values.delete("x_fk_#{lk}".to_sym) }
              grouped[key_values] << rec
            end

            # Assign back to parent objects
            eo[:rows].each do |parent|
              parent_key = Array(left_pks).map { |pk| parent.send(pk) }
              parent.associations[assoc_name] = grouped[parent_key] || []
            end
          end
        end
      end
    end
  end
end
