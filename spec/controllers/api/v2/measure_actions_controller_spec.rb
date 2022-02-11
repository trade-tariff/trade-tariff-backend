RSpec.describe Api::V2::MeasureActionsController, type: :controller do
  describe '#index' do
    subject(:do_request) { get :index }

    let(:json_body) { JSON.parse(do_request.body)['data'] }

    before do
      create(:measure_action, :with_description, action_code: '01')

      allow(TimeMachine).to receive(:at).and_call_original
    end

    it { is_expected.to have_http_status(:success) }

    it 'returns all measure actions' do
      expect(json_body).to eq(
        [
          {
            'attributes' => {
              'description' => 'Import/export not allowed after control',
              'validity_end_date' => nil,
              'validity_start_date' => Date.current.ago(3.years).as_json,
            },
            'id' => '01',
            'type' => 'measure_action',
          },
        ],
      )
    end

    it 'the TimeMachine receives the correct Date' do
      do_request
      expect(TimeMachine).to have_received(:at).with(Time.zone.today)
    end
  end
end
