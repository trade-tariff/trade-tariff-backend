require 'rails_helper'

RSpec.describe Api::V2::News::CollectionsController do
  describe 'GET #index' do
    subject(:rendered) { make_request && response }

    let :make_request do
      get api_news_collections_path(format: :json)
    end

    it_behaves_like 'a successful jsonapi response'
  end
end
