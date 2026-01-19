require 'date'

module Sequel
  module Plugins
    module TimeMachine
      BREXIT_DATE = Date.new(2020, 1, 31).freeze

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
          TradeTariffRequest.time_machine_now
        end

        # Returns true when associations should be filtered based on parent record validity
        # instead of the global point_in_time. See TimeMachine.with_relevant_validity_periods
        def relevant_query?
          TradeTariffRequest.time_machine_relevant
        end

        def validity_dates_filter(table = self,
                                  start_column: :validity_start_date,
                                  end_column: :validity_end_date)
          return Sequel.expr(true) if point_in_time.blank?

          table_name = if table.is_a?(Class) && table < Sequel::Model
                         table.table_name
                       else
                         table
                       end

          qualified_start_column = Sequel.qualify(table_name, start_column)
          qualified_end_column   = Sequel.qualify(table_name, end_column)

          (qualified_start_column <= point_in_time) &
            ((qualified_end_column >= point_in_time) | (qualified_end_column =~ nil))
        end
      end

      module InstanceMethods
        def current?
          now = Time.zone.now # This method will be called by a background JOB, therefore it does not use TradeTariffRequest.time_machine_now
          period_end_date = self.class.period_end_date_column.column
          period_start_date = self.class.period_start_date_column.column

          public_send(period_start_date) <= now &&
            (public_send(period_end_date).nil? || public_send(period_end_date) >= now)
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

        # Use for fetching records after Brexit happened.
        #
        # Example:
        #
        #   Measure.with_regulation_dates_query.since_brexit
        #
        # Will fetch all measures that are valid after Brexit.
        #
        def since_brexit
          filter { |o| o.>=(model.period_start_date_column, BREXIT_DATE) }
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
        # Filtering behavior depends on the relevant_query? flag:
        # - When relevant_query? is true (and parent provided): filters by parent's validity period
        # - When relevant_query? is false/nil: filters by global point_in_time
        #
        def with_actual(assoc, parent = nil)
          klass = assoc.to_s.classify.constantize

          # When relevant_query? is true, use parent's validity period to filter associations.
          # This ensures we get associations that were valid during the parent record's lifetime.
          if parent && !parent.instance_of?(Class) && klass.relevant_query?
            filter { |o| o.<=(klass.period_start_date_column, parent.send(parent.class.period_start_date_column.column)) & (o.>=(klass.period_end_date_column, parent.send(parent.class.period_end_date_column.column)) | ({ klass.period_end_date_column => nil })) }
          # Otherwise, use the global point_in_time if set
          elsif klass.point_in_time.present?
            filter { |o| o.<=(klass.period_start_date_column, klass.point_in_time) & (o.>=(klass.period_end_date_column, klass.point_in_time) | ({ klass.period_end_date_column => nil })) }
          else
            self
          end
        end

        def with_validity_dates(table = model.table_name,
                                start_column: :validity_start_date,
                                end_column: :validity_end_date)
          return self if model.point_in_time.blank?

          where do |_query|
            model.validity_dates_filter(table, start_column:, end_column:)
          end
        end
      end
    end
  end
end
