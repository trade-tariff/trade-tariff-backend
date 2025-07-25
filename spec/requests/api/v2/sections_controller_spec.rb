RSpec.describe Api::V2::SectionsController, :v2 do
  describe 'GET #index' do
    it_behaves_like 'a successful csv response' do
      let(:path) { '/uk/api/sections' }
      let(:expected_filename) { "uk-sections-#{Time.zone.today.iso8601}.csv" }

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
