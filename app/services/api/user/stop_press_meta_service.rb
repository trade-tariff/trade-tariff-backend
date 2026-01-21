module Api
  module User
    class StopPressMetaService
      def initialize(subscription)
        @subscription = subscription
      end

      def call
        {
          chapters: @subscription.user.chapter_ids.present? ? @subscription.user.chapter_ids.split(',').count : 'all',
          published: { yesterday: News::Item.where(start_date: Date.yesterday).for_chapters(@subscription.user.chapter_ids).all.count(&:emailable?) },
        }
      end

      private

      attr_reader :subscription
    end
  end
end
