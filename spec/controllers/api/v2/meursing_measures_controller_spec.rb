RSpec.describe Api::V2::MeursingMeasuresController do
  describe 'GET :index' do
    subject(:do_response) { get :index, params: { filter: { measure_sid: measure_sid, additional_code_id: additional_code_id } } }

    before { meursing_measure }

    let(:measure_sid) { root_measure.measure_sid }
    let(:additional_code_id) { '000' }

    let(:root_measure) { create(:measure) }

    let(:meursing_measure) do
      create(
        :meursing_measure,
        root_measure: root_measure,
        additional_code_id: '000',
      )
    end

    let(:expected_serialized_hash) do
      presented_meursing_measure = Api::V2::Measures::MeursingMeasurePresenter.new(meursing_measure.reload)

      Api::V2::Measures::MeursingMeasureSerializer.new(
        [presented_meursing_measure],
        include: %w[
          additional_code
          geographical_area
          measure_components
          measure_components.duty_expression
          measure_type
        ],
        meta: { resolved_duty_expression: '' },
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

      it { expect(JSON.parse(do_response.body)).to eq('data' => [], 'included' => [], 'meta' => { 'resolved_duty_expression' => '' }) }
    end
  end
end
