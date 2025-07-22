RSpec.describe Api::V2::HeadingsController, :v2 do
  describe 'GET #headings' do
    it_behaves_like 'a successful csv response' do
      let(:path) { "/uk/api/headings/#{heading.short_code}/commodities" }
      let(:expected_filename) { "uk-headings-#{heading.short_code}-commodities-#{Time.zone.today.iso8601}.csv" }
      let(:heading) { create(:heading, :non_declarable) }
    end
  end
end
