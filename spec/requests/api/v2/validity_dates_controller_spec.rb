require 'rails_helper'

RSpec.describe Api::V2::ValidityDatesController do
  subject(:rendered_page) { make_request && response }

  let(:json) { JSON.parse(rendered_page.body)['data'] }

  describe 'GET #index' do
    context 'with commodity' do
      let(:make_request) do
        get api_commodity_validity_dates_path(commodity),
            headers: { 'Accept' => 'application/vnd.uktt.v2' }
      end

      let(:commodity) { create :commodity }

      let(:expected_data) do
        [
          {
            'id' => "#{commodity.goods_nomenclature_item_id}-" \
                    "#{commodity.validity_start_date.to_i}-" \
                    "#{commodity.validity_end_date&.to_i}",
            'type' => 'validity_date',
            'attributes' => {
              'goods_nomenclature_item_id' => commodity.goods_nomenclature_item_id,
              'validity_start_date' => commodity.validity_start_date.iso8601(3),
              'validity_end_date' => commodity.validity_end_date&.iso8601(3),
            },
          },
        ]
      end

      it_behaves_like 'a successful jsonapi response'
      it { expect(json).to eql expected_data }
    end

    context 'with unknown commodity' do
      let(:make_request) do
        get api_commodity_validity_dates_path('1234567890'),
            headers: { 'Accept' => 'application/vnd.uktt.v2' }
      end

      it_behaves_like 'a successful jsonapi response'
      it { expect(json).to eql [] }
    end

    context 'with heading' do
      let(:make_request) do
        get api_heading_validity_dates_path(heading),
            headers: { 'Accept' => 'application/vnd.uktt.v2' }
      end

      let(:heading) { create :heading }

      let(:expected_data) do
        [
          {
            'id' => "#{heading.goods_nomenclature_item_id}-" \
                    "#{heading.validity_start_date.to_i}-" \
                    "#{heading.validity_end_date&.to_i}",
            'type' => 'validity_date',
            'attributes' => {
              'goods_nomenclature_item_id' => heading.goods_nomenclature_item_id,
              'validity_start_date' => heading.validity_start_date.iso8601(3),
              'validity_end_date' => heading.validity_end_date&.iso8601(3),
            },
          },
        ]
      end

      it_behaves_like 'a successful jsonapi response'
      it { expect(json).to eql expected_data }
    end

    context 'with unknown heading' do
      let(:make_request) do
        get api_heading_validity_dates_path('1234'),
            headers: { 'Accept' => 'application/vnd.uktt.v2' }
      end

      it_behaves_like 'a successful jsonapi response'
      it { expect(json).to eql [] }
    end
  end
end
