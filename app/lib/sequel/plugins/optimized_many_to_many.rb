# lib/sequel/plugins/optimized_many_to_many.rb
module Sequel
  module Plugins
    module OptimizedManyToMany

      module_function
      def join_conditions(right_key, right_pk, join_table, target_table, db = Sequel::Model.db)
        join_table_name = extract_table_name(join_table)

        Array(right_key).zip(Array(right_pk)).map do |join_key, pk|
          left  = db.literal(Sequel.qualify(join_table_name, join_key))
          right = db.literal(Sequel.qualify(target_table, pk))
          "#{left} = #{right}"
        end.join(" AND ")
      end

      def where_conditions(join_table, left_key, db = Sequel::Model.db)
        join_table_name = extract_table_name(join_table)
        db.literal(Sequel.qualify(join_table_name, left_key))
      end

      def qualify_order(order, target_table, associated_class)
        return nil unless order

        qualified_order = Array(order).map do |o|
          if o.is_a?(Sequel::SQL::OrderedExpression)
            Sequel::SQL::OrderedExpression.new(
              Sequel.qualify(target_table, o.expression),
              o.descending
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
        def many_to_many(name, opts = OPTS)
          opts = opts.dup
          model_class = self
          assoc_name  = name.to_sym

          # Full optimization: dataset + eager loader
          unless opts[:use_optimized] == false || opts[:use_optimized_dataset] == false || opts.key?(:dataset)
            opts[:dataset] = pg_optimized_many_to_many_dataset_proc
          end

          # Eager loader optimization can be toggled independently
          unless opts[:use_optimized] == false || opts.key?(:eager_loader)
            opts[:eager_loader] = pg_optimized_many_to_many_eager_loader_proc(assoc_name, model_class)
          end

          super(name, opts)
        end

        def pg_optimized_many_to_many_dataset_proc
          proc do |r|
            associated_class = r.associated_class
            left_pk = r[:left_primary_key]
            join_table = r[:join_table]
            left_key = r[:left_key]
            right_key = r[:right_key]
            right_pk = r[:right_primary_key]
            order = r[:order]
            target_table = associated_class.table_name

            join_conditions = OptimizedManyToMany.join_conditions(right_key, right_pk,join_table, target_table)
            order_sql = OptimizedManyToMany.qualify_order(order, target_table, associated_class)
            where_sql  = OptimizedManyToMany.where_conditions(join_table, left_key)

            sql = <<~SQL.strip
              SELECT #{target_table}.*
              FROM #{target_table}
              JOIN #{OptimizedManyToMany.table_ref(join_table)} ON #{join_conditions}
              WHERE #{where_sql} = ?
              #{order_sql ? "ORDER BY #{order_sql}" : ''}
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
            cte_name = "filter_ids"

            join_conditions = OptimizedManyToMany.join_conditions(right_key, right_pk, join_table, target_table)
            order_sql = OptimizedManyToMany.qualify_order(order, target_table, associated_class)

            sql = <<~SQL.strip
              WITH #{cte_name} AS (
                SELECT unnest(?) AS filter_id
              )
              SELECT #{target_table}.*, #{join_table}.#{left_key} AS x_foreign_key_x
              FROM #{target_table}
              JOIN #{OptimizedManyToMany.table_ref(join_table)} ON #{join_conditions}
              JOIN #{cte_name} fm ON fm.filter_id = #{join_table}.#{left_key}
              #{order_sql ? "ORDER BY #{order_sql}" : ''}
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
