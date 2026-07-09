RSpec.describe GeographicalAreaDescription do
  describe '.latest' do
    it 'orders by operation date descending' do
      create(:geographical_area_description, operation_date: 2.days.ago)
      latest_geographical_area_description = create(
        :geographical_area_description,
        operation_date: 1.day.ago,
      )

      expect(described_class.latest.first).to eq(latest_geographical_area_description)
    end
  end
end
