require 'rails_helper'

RSpec.describe Api::Feed::NewsItemsController do
  describe 'GET #index' do
    subject(:do_request) do
      get api_feed_news_items_path(format: :atom, service: service)

      response
    end

    let(:service) { '' }

    shared_context 'with news items' do
      before do
        uk_only_news_item
        xi_only_news_item
        both_services_news_item
      end

      let(:uk_only_news_item) { create(:news_item, :uk_only, :update_page) }
      let(:xi_only_news_item) { create(:news_item, :xi_only, :update_page) }
      let(:both_services_news_item) { create(:news_item, :both_services, :update_page) }
      let(:both_services_no_update_page_news_item) { create(:news_item, :both_services) }
    end

    context 'when there are news items and the uk service is passed' do
      let(:service) { 'uk' }

      include_context 'with news items'

      it { is_expected.to have_http_status(:ok) }

      it { expect(do_request.body).to include(uk_only_news_item.title) }
      it { expect(do_request.body).to include(both_services_news_item.title) }

      it { expect(do_request.body).not_to include(xi_only_news_item.title) }
      it { expect(do_request.body).not_to include(both_services_no_update_page_news_item.title) }
    end

    context 'when there are news items and the xi service is passed' do
      let(:service) { 'xi' }

      include_context 'with news items'

      it { is_expected.to have_http_status(:ok) }

      it { expect(do_request.body).to include(xi_only_news_item.title) }
      it { expect(do_request.body).to include(both_services_news_item.title) }

      it { expect(do_request.body).not_to include(uk_only_news_item.title) }
      it { expect(do_request.body).not_to include(both_services_no_update_page_news_item.title) }
    end

    context 'when there are news items and the service is not passed' do
      let(:service) { '' }

      include_context 'with news items'

      it { is_expected.to have_http_status(:ok) }

      it { expect(do_request.body).to include(uk_only_news_item.title) }
      it { expect(do_request.body).to include(both_services_news_item.title) }
      it { expect(do_request.body).to include(xi_only_news_item.title) }
      it { expect(do_request.body).not_to include(both_services_no_update_page_news_item.title) }
    end

    context 'when there are no news items' do
      let(:expected_news_items) do
        <<~NEWS_ITEMS
          <?xml version="1.0" encoding="UTF-8"?>
          <feed xml:lang="en-US" xmlns="http://www.w3.org/2005/Atom">
            <id>tag:www.example.com,2005:/feed/news_items?service=</id>
            <link rel="alternate" type="text/html" href="http://www.example.com"/>
            <link rel="self" type="application/atom+xml" href="http://www.example.com/feed/news_items?service="/>
            <title>Online Trade Tariff News Items</title>
          </feed>
        NEWS_ITEMS
      end

      it { is_expected.to have_http_status(:ok) }
      it { expect(do_request.body).to eq(expected_news_items) }
    end
  end
end
