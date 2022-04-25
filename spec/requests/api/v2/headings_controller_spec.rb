RSpec.describe Api::V2::HeadingsController do
  describe 'GET #commodities' do
    it_behaves_like 'a successful csv response' do
      let(:path) { "/headings/#{heading.short_code}/commodities" }
      let(:expected_filename) { "headings-#{heading.short_code}-commodities-#{Time.zone.today.iso8601}.csv" }
      let(:heading) { create(:heading, :non_declarable) }
    end
  end
end
