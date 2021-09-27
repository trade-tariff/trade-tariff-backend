RSpec.describe Api::V2::MeursingMeasuresController do
  describe 'GET :index' do
    subject(:do_response) { get :index, params: { filter: { measure_sid: measure_sid, additional_code_id: '000' } } }

    let(:measure_sid) { root_measure.measure_sid }

    let(:root_measure) do
      create(
        :measure,
        :with_meursing_measure,
        meursing_additional_code: additional_code_id,
      )
    end

    let(:expected_serialized_hash) do
      meursing_measure = MeursingMeasure.find(additional_code_id: '000')
      presented_meursing_measure = Api::V2::Measures::MeursingMeasurePresenter.new(meursing_measure)

      Api::V2::Measures::MeursingMeasureSerializer.new(
        [presented_meursing_measure],
        include: [
          'measure_type',
          'additional_code',
          'measure_components',
          'measure_components.duty_expression',
        ],
      ).serializable_hash.as_json
    end

    it { expect(do_response).to have_http_status(:success) }
    it { expect(JSON.parse(do_response.body)).to eq(expected_serialized_hash) }

    context 'when the root measure does not exist' do
      let(:measure_sid) { '999' }

      it { expect(do_response).to have_http_status(:not_found) }
    end

    context 'when the additional code id does not belong to a meursing measure' do
      let(:additional_code_id) { 'foo' }

      let(:expected_body) { { 'data' => [], 'included' => [] } }

      it { expect(JSON.parse(do_response.body)).to eq(expected_body) }
    end
  end
end
