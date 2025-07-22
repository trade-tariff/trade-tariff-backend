RSpec.describe Api::V2::ValidityPeriodsController, :v2 do
  shared_examples 'a correctly routing validity periods api request' do
    subject(:do_response) do
      api_get validity_period_path

      response
    end

    it 'calls the serializer service' do
      allow(ValidityPeriodSerializerService).to receive(:new).and_call_original

      do_response

      expect(ValidityPeriodSerializerService).to have_received(:new)
    end

    it_behaves_like 'a successful jsonapi response'
  end

  it_behaves_like 'a correctly routing validity periods api request' do
    let(:validity_period_path) { api_heading_validity_periods_path(goods_nomenclature) }
    let(:goods_nomenclature) { create(:heading, :with_deriving_goods_nomenclatures) }
  end

  it_behaves_like 'a correctly routing validity periods api request' do
    before do
      create(
        :commodity,
        :with_deriving_goods_nomenclatures,
        producline_suffix: '80',
        goods_nomenclature_item_id: '0101290000',
      )
    end

    let(:validity_period_path) { api_subheading_validity_periods_path(goods_nomenclature) }
    let(:goods_nomenclature) { Subheading.find(goods_nomenclature_item_id: '0101290000', producline_suffix: '80') }
  end

  it_behaves_like 'a correctly routing validity periods api request' do
    let(:validity_period_path) { api_commodity_validity_periods_path(goods_nomenclature) }
    let(:goods_nomenclature) { create(:commodity, :with_deriving_goods_nomenclatures) }
  end
end
