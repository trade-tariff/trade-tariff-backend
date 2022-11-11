require 'rails_helper'

RSpec.describe Api::V2::MeasuresController do
  describe 'GET #show' do
    subject(:rendered) { make_request && response }

    let(:measure) { create(:measure) }

    let :make_request do
      get api_measure_path(id: measure.measure_sid, format: :json),
          headers: { 'Accept' => 'application/vnd.uktt.v2' }
    end

    it_behaves_like 'a successful jsonapi response'
  end
end
