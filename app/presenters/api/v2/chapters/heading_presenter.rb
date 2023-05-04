module Api
  module V2
    module Chapters
      class HeadingPresenter < SimpleDelegator
        class << self
          def nest(headings)
            tree = {}

            headings.inject(nil) do |previous, heading|
              if previous.nil? # First iteration
                tree[heading] = nil
              elsif heading.producline_suffix > previous.producline_suffix
                tree[tree.keys.last] = [heading]
              elsif heading.producline_suffix < previous.producline_suffix
                tree[heading] = nil
              elsif tree[tree.keys.last].nil? # same PLS, and previous was at upper level
                tree[heading] = nil
              else # same PLS, and previous was at lower level
                tree[tree.keys.last] << heading
              end

              heading
            end

            tree
          end

          def wrap(headings)
            nest(headings).map { |heading, children| new(heading, children) }
          end
        end

        attr_reader :children

        def initialize(heading, children = nil)
          @children = (children || []).map(&self.class.method(:new))
          super(heading)
        end

        def child_ids
          children.map(&:goods_nomenclature_sid)
        end

        def leaf
          children.none?
        end
      end
    end
  end
end
