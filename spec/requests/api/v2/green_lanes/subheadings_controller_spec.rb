require 'rails_helper'

RSpec.describe Api::V2::GreenLanes::SubheadingsController do
  describe 'GET #show' do
    subject(:rendered) { make_request && response }

    before do
      create :subheading, goods_nomenclature_item_id: '1234560000' 
    end

    let :make_request do
      get api_green_lanes_subheading_path(123456, format: :json),
          headers: { 'Accept' => 'application/vnd.uktt.v2' }
    end

    it_behaves_like 'a successful jsonapi response',1
  end
end
