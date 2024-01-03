require 'rails_helper'

RSpec.describe Api::V2::GreenLanes::CategorisationsController do
  describe 'GET #index' do
    subject(:rendered) { make_request && response }

    let :make_request do
      get api_green_lanes_categorisations_path(format: :json),
          headers: { 'Accept' => 'application/vnd.uktt.v2' }
    end

    before do
      allow(::GreenLanes::Categorisation).to receive(:load_from_file).and_return(::GreenLanes::Categorisation.load_from_file(test_file))
    end

    context 'when categorisation data is found' do
      it_behaves_like 'a successful jsonapi response' do
        let(:test_file) { file_fixture 'green_lanes/categorisations.json' }
      end
    end
  end
end
