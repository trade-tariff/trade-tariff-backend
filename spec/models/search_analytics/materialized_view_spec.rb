# frozen_string_literal: true

RSpec.describe SearchAnalytics::MaterializedView do
  SearchAnalytics::MaterializedViews::MODELS.each do |model|
    it "is mixed into #{model}" do
      expect(model < Sequel::Model).to be(true)
      expect(model.included_modules).to include(described_class)
      expect(model.table_name.to_s).to start_with('search_analytics_')
    end

    it "refreshes #{model} through the model connection" do
      expect(model.db).to receive(:run).with("REFRESH MATERIALIZED VIEW CONCURRENTLY #{model.table_name}")
      model.refresh!
    end

    it "can refresh #{model} without the concurrent keyword" do
      expect(model.db).to receive(:run).with("REFRESH MATERIALIZED VIEW #{model.table_name}")
      model.refresh!(concurrently: false)
    end
  end
end
