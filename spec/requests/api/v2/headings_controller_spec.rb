RSpec.describe Api::V2::HeadingsController do
  describe 'GET #commodities' do
    it_behaves_like 'a successful csv response' do
      let(:path) { "/headings/#{heading.short_code}/commodities" }
      let(:heading) { create(:heading, :non_declarable) }
    end
  end
end
