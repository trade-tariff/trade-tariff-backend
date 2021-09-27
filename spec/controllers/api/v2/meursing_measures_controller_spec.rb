RSpec.describe Api::V2::MeursingMeasuresController do
  describe 'GET :index' do
    subject(:do_response) { get :index, params: { measures_sid: measure_sid, additional_code_id: additional_code_id } }

    let(:measure_sid) { root_measure.measure_sid }
    let(:additional_code_id) { '000' }

    let(:root_measure) do
      create(
        :measure,
        :with_meursing_measure,
        meursing_additional_code: additional_code_id,
      )
    end

    let(:meursing_measure) { MeursingMeasure.find(additional_code_id: '000') }

    let(:expected_serialized_hash) do
      require 'pry'; binding.pry

      result = Api::V2::Measures::MeasureSerializer.new(
        [meursing_measure],
        'measure_components.duty_expression',
      ).serializable_hash


      result
    end

    it { expect(do_response.body).to eq(expected_serialized_hash) }

    it 'initializes the CachedCommodityService' do
      get :show, params: { id: commodity }, format: :json

      expect(CachedCommodityService).to have_received(:new).with(commodity, Time.zone.today, nil)
    end
  end
end
