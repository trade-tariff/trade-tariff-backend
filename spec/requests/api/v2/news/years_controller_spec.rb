require 'rails_helper'

RSpec.describe Api::V2::News::YearsController do
  describe 'GET #index' do
    subject(:rendered) { make_request && response }

    let :make_request do
      get api_news_years_path(format: :json),
          headers: { 'Accept' => 'application/vnd.uktt.v2' }
    end

    it_behaves_like 'a successful jsonapi response'

    context 'with specific service' do
      let :make_request do
        get api_news_years_path(service: 'uk', format: :json),
            headers: { 'Accept' => 'application/vnd.uktt.v2' }
      end

      it_behaves_like 'a successful jsonapi response'
    end
  end
end
