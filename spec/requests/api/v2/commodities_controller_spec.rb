require 'rails_helper'

RSpec.describe Api::V2::CommoditiesController do
  let!(:commodity) do
    create(
      :commodity,
      :with_indent,
      :with_chapter,
      :with_heading,
      :with_description,
      :declarable,
    )
  end

  let(:v1_header) { { 'Accept' => 'application/vnd.uktt.v1' } }
  let(:v2_header) { { 'Accept' => 'application/vnd.uktt.v2' } }

  describe 'GET #show' do
    subject(:page_response) do
      get "/commodities/#{commodity.to_param}", headers: api_header
      response
    end

    before do
      allow_any_instance_of(ApiConstraints).to receive(:default).and_return default_version
    end

    context 'with v1 api default' do
      let(:default_version) { '1' }

      context 'with v1 api request' do
        let(:api_header) { v1_header }

        it_behaves_like 'a successful plain json response'

        it 'does include the objects data at the top level' do
          expect(JSON.parse(page_response.body)).to include 'goods_nomenclature_item_id'
        end
      end

      context 'with v2 api request' do
        let(:api_header) { v2_header }

        it_behaves_like 'a successful jsonapi response'

        it 'does not include the objects data at the top level' do
          expect(JSON.parse(page_response.body)).not_to include 'goods_nomenclature_item_id'
        end
      end
    end

    context 'with v2 api default' do
      let(:default_version) { '2' }

      context 'with v1 api request' do
        let(:api_header) { v1_header }

        it_behaves_like 'a successful plain json response'

        it 'does include the objects data at the top level' do
          expect(JSON.parse(page_response.body)).to include 'goods_nomenclature_item_id'
        end
      end

      context 'with v2 api request' do
        let(:api_header) { v2_header }

        it_behaves_like 'a successful jsonapi response'

        it 'does not include the objects data at the top level' do
          expect(JSON.parse(page_response.body)).not_to include 'goods_nomenclature_item_id'
        end
      end
    end
  end
end
