module Sequel
  module Plugins
    module Oplog
      CREATE_OPERATION = 'C'.freeze
      UPDATE_OPERATION = 'U'.freeze
      DESTROY_OPERATION = 'D'.freeze

      def self.configure(model, options = {})
        model_primary_key = options.fetch(:primary_key, model.primary_key)
        primary_key = [:oid, model_primary_key].flatten
        operation_class_name = :"#{model}::Operation"

        # Define ModelClass::Operation
        # e.g. Measure::Operation for measure oplog table
        operation_class = Class.new(Sequel::Model(:"#{model.table_name}_oplog")) do
          def record_class
            self.class.to_s.chomp('::Operation').constantize
          end
        end

        operation_class.one_to_one(
          :record,
          key: model_primary_key,
          primary_key: model_primary_key,
          foreign_key: model_primary_key,
          class_name: model,
        )
        operation_class.set_primary_key(primary_key)

        model.const_set(:Operation, operation_class)
        model.const_get(:Operation).unrestrict_primary_key

        # Associations
        model.one_to_one :source, key: :oid,
                                  primary_key: :oid,
                                  class_name: operation_class_name
        model.one_to_many :operations, key: primary_key,
                                       foreign_key: primary_key,
                                       primary_key:,
                                       class_name: operation_class_name

        # Delegations
        model.delegate :operation_klass, to: model

        model.plugin :identification
      end

      module InstanceMethods
        # Operation can be set to :update, :create and :delete
        # But they get persisted as U, C and D.
        # For some reasons it does not work for operation setter method (operation=) for child class
        # in rails = 5.1.6.1 and sequel >= 5.0.0
        # e.g. Chapter, Heading, Commodity
        def operation=(operation)
          self[:operation] = operation.present? ? operation[0].upcase : operation
        end

        # Force the CdsImporter not to import the current oplog instance
        def skip_import!
          @skip_import = true
        end

        # Determines whether the CdsImporter will imports the current oplog instance
        #
        # Ignored by Taric
        def skip_import?
          @skip_import == true
        end

        def operation
          case self[:operation]
          when CREATE_OPERATION then :create
          when UPDATE_OPERATION then :update
          when DESTROY_OPERATION then :destroy
          else
            :create
          end
        end

        ##
        # Will be called by https://github.com/jeremyevans/sequel/blob/5afb0d0e28a89e68f1823d77d23cfa57d6b88dad/lib/sequel/model/base.rb#L1549
        # @note fixes `NotImplementedError: You should be inserting model instances`
        # Since sequel 5.4.0 method needs to return `nil` to execute `_insert_raw`
        # See https://github.com/jeremyevans/sequel/compare/5.3.0...5.4.0#diff-a5b2d78790313f597d88b4f2977a7d57R1638
        def _insert_select_raw(_dataset)
          nil
        end

        def _insert_raw(_dataset)
          self.operation = :create

          values = self.values.slice(*operation_klass.columns).except(:oid)
          if operation_klass.columns.include?(:created_at)
            values.merge!(created_at: operation_klass.dataset.current_datetime)
          end

          operation_klass.insert(values)
        end

        def _destroy_delete
          self.operation = :destroy

          values = self.values.slice(*operation_klass.columns).except(:oid)
          if operation_klass.columns.include?(:created_at)
            values.merge!(created_at: operation_klass.dataset.current_datetime)
          end

          operation_klass.insert(values)
        end

        def _update_columns(_columns)
          self.operation = :update

          values = self.values.slice(*operation_klass.columns).except(:oid)
          if operation_klass.columns.include?(:created_at)
            values.merge!(created_at: operation_klass.dataset.current_datetime)
          end

          operation_klass.insert(values)
        end
      end

      # Enforce operation logging by un-defining operations that do not use
      # model instances (as Insert/Update/Delete operations will not be created)
      module ClassMethods
        # Hide oplog columns if asked
        def columns
          super - %i[oid operation operation_date]
        end

        def insert(*_args)
          raise NotImplementedError, 'You should be instantiating model and saving instances.'
        end

        def operation_klass
          @operation_klass ||= "#{self}::Operation".constantize
        end
      end

      module DatasetMethods
        def update(*_attr)
          # noop
        end

        def insert
          raise NotImplementedError, 'You should be inserting model instances.'
        end

        def delete
          raise NotImplementedError, 'You should be *destroying* model instances.'
        end
      end
    end
  end
end
