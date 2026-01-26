module Api
  module User
    class StopPressMetaService
      ALL = 'all'.freeze

      def initialize(subscription)
        @subscription = subscription
      end

      def call
        {
          chapters: chapters_count,
          published: { yesterday: News::Item.where(start_date: Date.yesterday).for_chapters(@subscription.user.chapter_ids).all.count(&:emailable?) },
        }
      end

      private

      attr_reader :subscription

      def chapters_count
        if @subscription.user.chapter_ids.present?
          count = @subscription.user.chapter_ids.split(',').count
          count == Chapter.count ? ALL : count
        else
          ALL
        end
      end
    end
  end
end
