require 'rails_helper'

RSpec.describe Api::V2::ValidityPeriodsController do
  subject(:rendered_page) { make_request && response }

  let(:json) { JSON.parse(rendered_page.body)['data'] }

  describe 'GET #index' do
    context 'when a commodity' do
      let(:make_request) do
        get api_commodity_validity_periods_path(commodity),
            headers: { 'Accept' => 'application/vnd.uktt.v2' }
      end

      let(:commodity) { create(:commodity, :with_heading) }

      it_behaves_like 'a successful jsonapi response'

      it { expect(json).not_to eq([]) }
    end

    context 'when a unknown commodity' do
      let(:make_request) do
        get api_commodity_validity_periods_path('1234567890'),
            headers: { 'Accept' => 'application/vnd.uktt.v2' }
      end

      it_behaves_like 'a successful jsonapi response'

      it { expect(json).to eq([]) }
    end

    context 'when a subheading' do
      let(:make_request) do
        get api_subheading_validity_periods_path(subheading),
            headers: { 'Accept' => 'application/vnd.uktt.v2' }
      end

      let(:subheading) do
        create(:commodity, producline_suffix: '10', goods_nomenclature_item_id: '0101290000')

        Subheading.by_code('0101290000').take
      end

      it_behaves_like 'a successful jsonapi response'

      it { expect(json).not_to eq([]) }
    end

    context 'when a unknown subheading' do
      let(:make_request) do
        get api_subheading_validity_periods_path('0101290000-20'),
            headers: { 'Accept' => 'application/vnd.uktt.v2' }
      end

      it_behaves_like 'a successful jsonapi response'

      it { expect(json).to eq([]) }
    end

    context 'when a heading' do
      let(:make_request) do
        get api_heading_validity_periods_path(heading),
            headers: { 'Accept' => 'application/vnd.uktt.v2' }
      end

      let(:heading) { create :heading }

      it_behaves_like 'a successful jsonapi response'

      it { expect(json).not_to eq([]) }
    end

    context 'when a unknown heading' do
      let(:make_request) do
        get api_heading_validity_periods_path('1234'),
            headers: { 'Accept' => 'application/vnd.uktt.v2' }
      end

      it_behaves_like 'a successful jsonapi response'

      it { expect(json).to eq([]) }
    end
  end
end
