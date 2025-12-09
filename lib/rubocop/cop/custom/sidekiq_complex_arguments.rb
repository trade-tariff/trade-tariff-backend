require 'rubocop'

module RuboCop
  module Cop
    module Custom
      class SidekiqComplexArguments < Base
        MSG = 'Do not pass complex data structures (Hash/Array) to Sidekiq jobs. Pass IDs (Scalars) instead to prevent PII leaks and reduce Redis load.'.freeze

        # Matches: Worker.perform_async(...) or Worker.perform_in(..., ...)
        # Captures arguments passed to the method
        def_node_matcher :sidekiq_perform?, <<~PATTERN
          (send _ {:perform_async :perform_in :perform_at} $...)
        PATTERN

        def on_send(node)
          # Check if this is a Sidekiq perform call
          sidekiq_perform?(node) do |arguments|
            # perform_in/at have a time argument first, skip it
            args_to_check = if %i[perform_in perform_at].include?(node.method_name)
                              arguments.drop(1)
                            else
                              arguments
                            end

            args_to_check.each do |arg|
              check_argument(arg)
            end
          end
        end

        private

        def check_argument(arg)
          # We strictly forbid Hash literals and Array literals
          if arg.hash_type? || arg.array_type?
            add_offense(arg)
          end

          if arg.send_type?
            method_name = arg.method_name.to_s

            if method_name.end_with?('params', 'data')
              add_offense(arg, message: 'Do not pass controller _params or complex data directly to Sidekiq.')
            end
          end
        end
      end
    end
  end
end
