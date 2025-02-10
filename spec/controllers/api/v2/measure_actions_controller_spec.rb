RSpec.describe Api::V2::MeasureActionsController, type: :controller do
  routes { V2Api.routes }

  describe '#index' do
    subject(:do_request) { get :index }

    let(:json_body) { JSON.parse(do_request.body)['data'] }
    let(:validity_end_date) { nil }

    before do
      create(:measure_action, :with_description, action_code: '01', validity_end_date:)

      allow(TimeMachine).to receive(:at).and_call_original
    end

    it { is_expected.to have_http_status(:success) }

    it 'returns all measure actions' do
      expect(json_body).to eq(
        [
          {
            'attributes' => {
              'description' => 'Import/export not allowed after control',
              'validity_start_date' => 3.years.ago.beginning_of_day.as_json,
              'validity_end_date' => nil,
            },
            'id' => '01',
            'type' => 'measure_action',
          },
        ],
      )
    end

    context 'when the validity_end_date is set to a past date' do
      let(:validity_end_date) { 1.day.ago }

      it { expect(json_body).to eq [] }
    end
  end
end
