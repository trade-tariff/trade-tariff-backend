module Sequel
  module Plugins
    module TimeMachine
      def self.configure(model, opts = {})
        model.period_start_date_column = opts[:period_start_column]
        model.period_end_date_column = opts[:period_end_column]

        model.delegate :point_in_time, to: model
      end

      module ClassMethods
        attr_writer :period_start_date_column, :period_end_date_column

        Plugins.def_dataset_methods self, %i[actual with_actual]

        # Inheriting classes have the same start/end date columns
        def inherited(subclass)
          super

          ds = dataset

          subclass.period_start_date_column = period_start_date_column
          subclass.period_end_date_column = period_end_date_column
          subclass.instance_eval do
            set_dataset(ds)
          end
        end

        def period_start_date_column
          @period_start_date_column.presence || Sequel.qualify(table_name, :validity_start_date)
        end

        def period_end_date_column
          @period_end_date_column.presence || Sequel.qualify(table_name, :validity_end_date)
        end

        def point_in_time
          Thread.current[::TimeMachine::THREAD_DATETIME_KEY]
        end

        def relevant_query?
          Thread.current[::TimeMachine::THREAD_RELEVANT_KEY]
        end
      end

      module InstanceMethods
        # Use for fetching associated records with relevant validity period
        # to parent record.
        def actual_or_relevant(klass)
          if self.class.point_in_time.present?
            klass.filter { |o| o.<=(self.class.period_start_date_column, self.class.point_in_time) & (o.>=(self.class.period_end_date_column, self.class.point_in_time) | ({ self.class.period_end_date_column => nil })) }
          elsif self.class.relevant_query?
            klass.filter { |o| o.<=(klass.period_start_date_column, send(self.class.period_start_date_column.column)) & (o.>=(klass.period_end_date_column, send(self.class.period_end_date_column.column)) | ({ klass.period_end_date_column => nil })) }
          else
            klass
          end
        end
      end

      module DatasetMethods
        # Use for fetching record inside TimeMachine block.
        #
        # Example:
        #
        #   TimeMachine.now { Commodity.actual.first }
        #
        # Will fetch first commodity that is valid at this point in time.
        # Invoking outside time machine block will probably yield no as
        # current time variable will be nil.
        #
        def actual
          if model.point_in_time.present?
            filter { |o| o.<=(model.period_start_date_column, model.point_in_time) & (o.>=(model.period_end_date_column, model.point_in_time) | ({ model.period_end_date_column => nil })) }
          else
            self
          end
        end

        # Use for extending datasets and associations, so that specified
        # klass would respect current time in TimeMachine.
        #
        # Example
        #
        #   TimeMachine.now { Footnote.actual
        #                             .with_actual(FootnoteDescriptionPeriod)
        #                             .joins(:footnote_description_periods)
        #                             .first }
        #
        # Useful for forming time bound associations.
        #
        def with_actual(assoc, parent = nil)
          klass = assoc.to_s.classify.constantize

          # TODO: to review after sequel upgrade. code: !parent.instance_of?(Class)
          if parent && !parent.instance_of?(Class) && klass.relevant_query?
            filter { |o| o.<=(klass.period_start_date_column, parent.send(parent.class.period_start_date_column.column)) & (o.>=(klass.period_end_date_column, parent.send(parent.class.period_end_date_column.column)) | ({ klass.period_end_date_column => nil })) }
          elsif klass.point_in_time.present?
            filter { |o| o.<=(klass.period_start_date_column, klass.point_in_time) & (o.>=(klass.period_end_date_column, klass.point_in_time) | ({ klass.period_end_date_column => nil })) }
          else
            self
          end
        end
      end
    end
  end
end
