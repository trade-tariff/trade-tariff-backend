RSpec.describe HeadingService::Serialization::DeclarableService do
  describe '#serializable_hash' do
    around do |example|
      Thread.current[:jsonapi_query_options] = {
        include_requested: true,
        include: [],
        fields: { heading: %i[goods_nomenclature_item_id] },
      }

      example.run
    ensure
      Thread.current[:jsonapi_query_options] = nil
    end

    it 'does not query chapter or section notes when sparse fields do not need them' do
      heading = create(:heading, :with_indent, :with_description, :declarable, :with_chapter)

      sql = []
      subscriber = ActiveSupport::Notifications.subscribe(/sql\.sequel/) do |*args|
        event = ActiveSupport::Notifications::Event.new(*args)
        sql << event.payload[:sql].to_s
      end

      begin
        described_class.new(heading, {}).serializable_hash
      ensure
        ActiveSupport::Notifications.unsubscribe(subscriber)
      end

      forbidden_sql = sql.grep(/chapter_notes|section_notes/i)
      expect(forbidden_sql).to be_empty
    end
  end
end
