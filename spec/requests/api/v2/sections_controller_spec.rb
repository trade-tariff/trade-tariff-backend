RSpec.describe Api::V2::SectionsController do
  describe 'GET #index' do
    subject(:do_request) { make_request && response }

    let(:make_request) { get '/sections.csv' }

    before do
      create(
        :section,
        id: 18,
        position: 18,
        numeral: 'XVIII',
        title: 'Optical, photographic, cinematographic, measuring',
      )
    end

    it_behaves_like 'a successful csv response'
  end
end
