# lib/sequel/plugins/optimized_many_to_many.rb
module Sequel
  module Plugins
    module OptimizedManyToMany
      module ClassMethods
        def many_to_many(name, opts = OPTS)
          opts = opts.dup
          model_class = self
          assoc_name  = name.to_sym

          # Full optimization: dataset + eager loader
          unless opts[:use_optimized] == false || opts.key?(:dataset)
            opts[:dataset] = pg_optimized_many_to_many_dataset_proc
          end

          # Eager loader optimization can be toggled independently
          unless opts[:use_optimized] == false || opts.key?(:eager_loader)
            opts[:eager_loader] = pg_optimized_many_to_many_eager_loader_proc(assoc_name, model_class)
          end

          super(name, opts)
        end

        private

        def pg_optimized_many_to_many_dataset_proc
          proc do |r|
            associated_class = r.associated_class
            left_pk = r[:left_primary_key]
            join_table = r[:join_table]
            left_key = r[:left_key]
            right_key = r[:right_key]
            target_table = associated_class.table_name
            right_pk = r[:right_primary_key]
            order = r[:order]

            sql = <<~SQL.strip
              SELECT #{target_table}.*
              FROM #{target_table}
              JOIN #{join_table} ON #{join_table}.#{right_key} = #{target_table}.#{right_pk}
              WHERE #{join_table}.#{left_key} = ?
              #{order ? "ORDER BY #{associated_class.dataset.literal(order)}" : ''}
            SQL

            associated_class.with_sql(sql, send(left_pk))
          end
        end

        def pg_optimized_many_to_many_eager_loader_proc(assoc_name, model_class)
          proc do |eo|
            refl = model_class.association_reflection(assoc_name)
            associated_class = refl.associated_class
            left_pk = refl[:left_primary_key]
            ids = eo[:id_map].keys
            join_table = refl[:join_table]
            left_key = refl[:left_key]
            right_key = refl[:right_key]
            target_table = associated_class.table_name
            right_pk = refl[:right_primary_key]
            order = refl[:order]
            cte_name = "filter_#{left_pk}s"

            sql = <<~SQL.strip
              WITH #{cte_name} AS (
                SELECT unnest(?) AS #{left_pk}
              )
              SELECT #{target_table}.*, #{join_table}.#{left_key} AS x_foreign_key_x
              FROM #{target_table}
              JOIN #{join_table} ON #{join_table}.#{right_key} = #{target_table}.#{right_pk}
              JOIN #{cte_name} fm ON fm.#{left_pk} = #{join_table}.#{left_key}
              #{order ? "ORDER BY #{associated_class.dataset.literal(order)}" : ''}
            SQL

            dataset = associated_class.with_sql(sql, Sequel.pg_array(ids, :integer))
            records = dataset.all

            # Load nested associations if requested
            if eo[:associations]
              associated_class.eager(eo[:associations])
            end

            # Group by foreign key
            grouped = Hash.new { |h, k| h[k] = [] }
            records.each do |rec|
              msid = rec.values.delete(:x_foreign_key_x)
              grouped[msid] << rec
            end

            # Assign back to parent objects
            eo[:rows].each do |parent|
              parent.associations[assoc_name] = grouped[parent.send(left_pk)] || []
            end
          end
        end
      end
    end
  end
end
