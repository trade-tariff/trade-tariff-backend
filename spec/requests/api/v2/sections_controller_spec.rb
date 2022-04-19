RSpec.describe Api::V2::SectionsController do
  describe 'GET #index' do
    subject(:do_request) { make_request && response }

    before do
      create(
        :section,
        id: 18,
        position: 18,
        numeral: 'XVIII',
        title: 'Optical, photographic, cinematographic, measuring',
      )
    end

    context 'when using the mime suffix to configure the mime type' do
      let(:make_request) { get '/sections.csv' }

      it_behaves_like 'a successful csv response'
    end

    context 'when using Accept header to configure the mime type' do
      let(:make_request) { get '/sections', headers: { 'ACCEPT' => 'text/csv' } }

      it_behaves_like 'a successful csv response'
    end
  end
end
