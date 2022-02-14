RSpec.describe Api::V2::MeasureConditionCodesController, type: :controller do
  describe '#index' do
    subject(:do_request) { get :index }

    let(:json_body) { JSON.parse(do_request.body)['data'] }

    before do
      create(:measure_condition_code, :with_description, condition_code: 'C')

      allow(TimeMachine).to receive(:at).and_call_original
    end

    it { is_expected.to have_http_status(:success) }

    it 'returns all measure actions' do
      expect(json_body).to eq(
        [
          {
            'id' => 'C',
            'type' => 'measure_condition_code',
            'attributes' => {
              'description' => 'Presentation of a certificate/licence/document',
              'validity_start_date' => Date.current.ago(3.years).as_json,
              'validity_end_date' => nil,
            },
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
