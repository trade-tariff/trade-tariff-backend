# lib/sequel/plugins/optimized_many_to_many.rb
require_relative 'optimized_many_to_many/sql_helpers'

module Sequel
  module Plugins
    module OptimizedManyToMany
      EagerLoadQuery = Data.define(:sql, :bind_args, :left_keys, :left_pks)
      extend SqlHelpers

    module_function

      def eager_loader_query(reflection, ids)
        associated_class = reflection.associated_class
        left_pks = Array(reflection[:left_primary_key])
        join_table = reflection[:join_table]
        left_keys = Array(reflection[:left_key])
        right_keys = Array(reflection[:right_key])
        target_table = associated_class.table_name
        right_pks = Array(reflection[:right_primary_key])
        order = reflection[:order]
        join_conditions = join_conditions(right_keys, right_pks, join_table, target_table)
        order_sql = qualify_order(order, target_table, associated_class)
        fk_selects = left_keys.map { |lk| "#{join_table}.#{lk} AS x_fk_#{lk}" }.join(', ')

        if left_pks.size == 1
          simple_eager_loader_query(join_table, left_keys, left_pks, target_table, fk_selects, join_conditions, order_sql, ids)
        else
          composite_eager_loader_query(join_table, left_keys, left_pks, target_table, fk_selects, join_conditions, order_sql, ids)
        end
      end

      def simple_eager_loader_query(join_table, left_keys, left_pks, target_table, fk_selects, join_conditions, order_sql, ids)
        sql = <<~SQL.strip
          SELECT #{target_table}.*, #{fk_selects}
          FROM #{table_ref(join_table)}
          JOIN #{target_table} ON #{join_conditions}
          WHERE #{join_table}.#{left_keys.first} = ANY(?)
          #{order_sql ? "ORDER BY #{order_sql}" : ''}
        SQL

        EagerLoadQuery.new(sql, [Sequel.pg_array(ids)], left_keys, left_pks)
      end

      def composite_eager_loader_query(join_table, left_keys, left_pks, target_table, fk_selects, join_conditions, order_sql, ids)
        cte_columns = left_pks.map(&:to_s).join(', ')
        unnest_args = left_pks.map { 'unnest(?)' }.join(', ')
        bind_args = left_pks.map.with_index { |_pk, i| Sequel.pg_array(ids.map { |key| Array(key)[i] }) }
        join_predicates = left_keys.zip(left_pks).map { |lk, pk| "filter_ids.#{pk} = #{join_table}.#{lk}" }.join(' AND ')

        sql = <<~SQL.strip
          WITH filter_ids (#{cte_columns}) AS (
            SELECT #{unnest_args}
          )
          SELECT #{target_table}.*, #{fk_selects}
          FROM #{target_table}
          JOIN #{table_ref(join_table)} ON #{join_conditions}
          JOIN filter_ids ON #{join_predicates}
          #{order_sql ? "ORDER BY #{order_sql}" : ''}
        SQL

        EagerLoadQuery.new(sql, bind_args, left_keys, left_pks)
      end

      def eager_load_nested_associations(associated_class, associations, records)
        return unless associations && records.any?

        associated_class.eager(associations).send(:eager_load, records)
      end

      def assign_eager_loaded_associations(rows, records, assoc_name, left_keys, left_pks)
        grouped = Hash.new { |h, k| h[k] = [] }
        records.each do |record|
          key_values = left_keys.map { |lk| record.values.delete("x_fk_#{lk}".to_sym) }
          grouped[key_values] << record
        end

        rows.each do |parent|
          parent_key = Array(left_pks).map { |pk| parent.send(pk) }
          parent.associations[assoc_name] = grouped[parent_key] || []
        end
      end

      module ClassMethods
        def many_to_many(name, opts = OPTS, &block)
          opts = opts.dup
          model_class = self
          assoc_name = name.to_sym

          if opts[:use_optimized]
            # Full optimization: dataset + eager loader
            unless opts[:use_optimized_dataset] == false || opts.key?(:dataset) || block
              opts[:dataset] = pg_optimized_many_to_many_dataset_proc
            end

            # Eager loader optimization can be toggled independently
            unless opts.key?(:eager_loader)
              opts[:eager_loader] = pg_optimized_many_to_many_eager_loader_proc(assoc_name, model_class)
            end
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
            query = OptimizedManyToMany.eager_loader_query(refl, eo[:id_map].keys)
            dataset = associated_class.with_sql(query.sql, *query.bind_args)
            records = dataset.all

            OptimizedManyToMany.eager_load_nested_associations(associated_class, eo[:associations], records)
            OptimizedManyToMany.assign_eager_loaded_associations(eo[:rows], records, assoc_name, query.left_keys, query.left_pks)
          end
        end
      end
    end
  end
end
