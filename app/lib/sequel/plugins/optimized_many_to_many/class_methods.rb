module Sequel
  module Plugins
    module OptimizedManyToMany
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
            OptimizedManyToMany.assign_eager_loaded_associations(
              eo[:rows],
              records,
              assoc_name,
              query.left_keys,
              query.left_pks,
            )
          end
        end
      end
    end
  end
end
