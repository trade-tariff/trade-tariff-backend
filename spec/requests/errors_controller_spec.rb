require 'rails_helper'

RSpec.describe ErrorsController do
  subject(:rendered) { make_request && response }

  let(:json_response) { JSON.parse(rendered.body) }

  shared_examples 'a json error response' do |status_code, message|
    it { is_expected.to have_http_status status_code }
    it { is_expected.to have_attributes media_type: 'application/json' }
    it { expect(json_response).to include 'error' => "#{status_code} - #{message}" }
  end

  shared_examples 'a csv or json error response' do |status_code, message|
    context 'with html request' do
      let(:make_request) { get "/#{status_code}" }

      it_behaves_like 'a json error response', status_code, message
    end

    context 'with json request' do
      let(:make_request) { get "/#{status_code}.json" }

      it_behaves_like 'a json error response', status_code, message
    end

    context 'with jsonapi request' do
      let :make_request do
        get "/#{status_code}.json",
            headers: { 'Accept' => 'application/vnd.uktt.v2' }
      end

      it { is_expected.to have_http_status status_code }
      it { is_expected.to have_attributes media_type: 'application/json' }
      it { expect(json_response).to include 'errors' => [{ 'detail' => "#{status_code} - #{message}" }] }
    end

    context 'with csv request' do
      let(:make_request) { get "/#{status_code}.csv" }

      it { is_expected.to have_http_status status_code }
      it { is_expected.to have_attributes media_type: 'text/csv' }
      it { is_expected.to have_attributes body: %(Code,Error\n#{status_code},#{message}\n) }
    end

    context 'with other request' do
      let(:make_request) { get "/#{status_code}.pdf" }

      it_behaves_like 'a json error response', status_code, message
    end
  end

  describe 'GET #bad_request' do
    it_behaves_like 'a csv or json error response',
                    400,
                    'Bad request: API documentation is available at https://api.trade-tariff.service.gov.uk/'
  end

  describe 'GET #not_found' do
    it_behaves_like 'a csv or json error response', 404, 'Not Found'
  end

  describe 'GET #unprocessable_entity' do
    it_behaves_like 'a csv or json error response',
                    422,
                    'Unprocessable entity: API documentation is available at https://api.trade-tariff.service.gov.uk/'
  end

  describe 'GET #internal_server_error' do
    it_behaves_like 'a csv or json error response',
                    500,
                    'Internal Server Error: Please contact the Tariff team for help with this issue.'
  end

  describe 'GET #serice_unavailable' do
    it_behaves_like 'a csv or json error response', 503, 'Service is unavailable'
  end
end
