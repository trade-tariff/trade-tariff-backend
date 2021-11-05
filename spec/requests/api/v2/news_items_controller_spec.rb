require 'rails_helper'

RSpec.describe Api::V2::NewsItemsController do
  describe 'GET #index' do
    subject(:rendered) { make_request && response }

    let :make_request do
      get api_news_items_path(format: :json),
          headers: { 'Accept' => 'application/vnd.uktt.v2' }
    end

    it_behaves_like 'a successful jsonapi response'

    context 'for uk pages' do
      let :make_request do
        get api_news_items_path(service: 'uk', format: :json),
            headers: { 'Accept' => 'application/vnd.uktt.v2' }
      end

      it_behaves_like 'a successful jsonapi response'

      context 'with only items for home page' do
        let :make_request do
          get api_news_items_path(service: 'uk', target: 'home', format: :json),
              headers: { 'Accept' => 'application/vnd.uktt.v2' }
        end

        it_behaves_like 'a successful jsonapi response'
      end

      context 'with only items for updates page' do
        let :make_request do
          get api_news_items_path(service: 'uk', target: 'updates', format: :json),
              headers: { 'Accept' => 'application/vnd.uktt.v2' }
        end

        it_behaves_like 'a successful jsonapi response'
      end

      context 'with unknown target' do
        let :make_request do
          get api_news_items_path(service: 'uk', target: 'unknown', format: :json),
              headers: { 'Accept' => 'application/vnd.uktt.v2' }
        end

        it { is_expected.to have_http_status :not_found }
      end
    end

    context 'for xi pages' do
      let :make_request do
        get api_news_items_path(service: 'xi', format: :json),
            headers: { 'Accept' => 'application/vnd.uktt.v2' }
      end

      it_behaves_like 'a successful jsonapi response'
    end

    context 'for unknown service pages' do
      let :make_request do
        get api_news_items_path(service: 'uk', format: :json),
            headers: { 'Accept' => 'application/vnd.uktt.v2' }

        it { is_expected.to have_http_status :not_found }
      end
    end
  end

  describe 'GET #show' do
    subject(:rendered) { make_request && response }

    let(:news_item) { create :news_item }

    let :make_request do
      get api_news_item_path(news_item.id, format: :json),
          headers: { 'Accept' => 'application/vnd.uktt.v2' }
    end

    it_behaves_like 'a successful jsonapi response'
  end
end
