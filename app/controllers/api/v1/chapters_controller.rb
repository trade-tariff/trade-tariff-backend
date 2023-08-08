module Api
  module V1
    class ChaptersController < ApiController
      def index
        cache_key = "_v1_chapters-#{actual_date}-view"

        serialized_result = Rails.cache.fetch(cache_key, expires_at: actual_date.end_of_day) do
          render_to_string(
            template: 'api/v1/chapters/index',
            formats: [:json],
            locals: { chapters: },
          )
        end

        render json: serialized_result
      end

      def show
        cache_key = "_v1_chapter-#{chapter_id}-#{actual_date}-view"

        serialized_result = Rails.cache.fetch(cache_key, expires_at: actual_date.end_of_day) do
          render_to_string(
            template: 'api/v1/chapters/show',
            formats: [:json],
            locals: { chapter:, headings: root_headings },
          )
        end

        render json: serialized_result
      end

      def changes
        cache_key = "_v1_chapter-#{chapter_id}-#{actual_date}/changes-view"

        serialized_result = Rails.cache.fetch(cache_key, expires_at: actual_date.end_of_day) do
          changes = chapter.changes.where { |o| o.operation_date <= actual_date }
          changes = ChangeLog.new(changes).changes

          render_to_string(
            template: 'api/v1/changes/changes',
            formats: [:json],
            locals: { changes: },
          )
        end

        render json: serialized_result
      end

      private

      def chapter
        @chapter ||= Chapter.actual
          .by_code(chapter_id)
          .non_hidden
          .take
      end

      def chapters
        @chapters ||= Chapter.eager(:chapter_note).all
      end

      def root_headings
        groups = []
        group = { group_lead: nil, group_members: [] }

        chapter.children.each do |heading|
          if heading.producline_suffix == GoodsNomenclatureIndent::NON_GROUPING_PRODUCTLINE_SUFFIX
            if group[:group_lead].present?
              group[:group_members] << heading
            else
              group[:group_lead] = heading
              group[:group_members] = []

              groups << group

              group = { group_lead: nil, group_members: [] }
            end
          else
            group = { group_lead: heading, group_members: [] }
            groups << group
          end
        end

        groups.map do |result|
          RootHeadingPresenter.new(result[:group_lead], result[:group_members])
        end
      end

      def chapter_id
        params[:id]
      end
    end

    class RootHeadingPresenter < WrapDelegator
      attr_reader :children

      def initialize(heading, children)
        super(heading)

        @children = children.any? ? RootHeadingPresenter.wrap(children, []) : []
      end

      def leaf
        producline_suffix == GoodsNomenclatureIndent::NON_GROUPING_PRODUCTLINE_SUFFIX && children.none?
      end

      def declarable
        declarable?
      end
    end
  end
end
