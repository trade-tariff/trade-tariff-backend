RSpec.describe Api::V2::SectionsController do
  describe 'GET #index' do
    it_behaves_like 'a successful csv response' do
      let(:path) { '/sections' }
      let(:expected_filename) { "sections-#{Time.zone.today.iso8601}.csv" }

      before do
        create(
          :section,
          id: 18,
          position: 18,
          numeral: 'XVIII',
          title: 'Optical, photographic, cinematographic, measuring',
        )
      end
    end
  end
end
