RSpec.describe CachedQuotaOrderNumberService do
  describe '#call' do
    subject(:result) { described_class.new.call.as_json }

    before do
      create(
        :quota_order_number,
        :with_quota_definition,
        :current,
        :current_definition,
        quota_definition_sid: 1,
        quota_order_number_sid: 5,
        quota_order_number_id: '000001',
        validity_end_date:,
      )
    end

    context 'when quota order numbers are current' do
      let(:validity_end_date) { nil }
      let(:pattern) do
        {
          'data' => [
            {
              'id' => match(/\d+/),
              'type' => 'quota_order_number',
              'attributes' => {
                'quota_order_number_sid' => be_a(Integer),
                'validity_start_date' => 4.years.ago.beginning_of_day.as_json,
                'validity_end_date' => nil,
              },
              'relationships' => {
                'quota_definition' => {
                  'data' => {
                    'id' => match(/\d+/),
                    'type' => 'quota_definition',
                  },
                },
              },
            },
          ],
          'included' => [
            {
              'id' => match(/\d+/),
              'type' => 'quota_definition',
              'attributes' => {
                'quota_order_number_id' => match(/\d+/),
                'validity_start_date' => 4.years.ago.beginning_of_day.as_json,
                'validity_end_date' => nil,
                'initial_volume' => nil,
                'measurement_unit_code' => be_present,
                'measurement_unit_qualifier_code' => be_present,
                'maximum_precision' => nil,
                'critical_threshold' => be_a(Integer),
                'measurement_unit' => nil,
              },
              'relationships' => { 'measures' => { 'data' => [] } },
            },
          ],
        }
      end

      it { TimeMachine.now { expect(result).to include_json(pattern) } }

      it 'rails cache receives fetch with the correct key' do
        allow(Rails.cache).to receive(:fetch).and_call_original

        TimeMachine.now { result }

        expect(Rails.cache)
          .to have_received(:fetch)
          .with("_quota-order-numbers-#{Time.zone.today.iso8601}", expires_in: 1.day)
      end
    end

    context 'when quota order numbers are not current' do
      let(:validity_end_date) { 1.day.ago }
      let(:pattern) { { 'data' => [], 'included' => [] } }

      it { TimeMachine.now { expect(result).to eq(pattern) } }

      it 'rails cache receives fetch with the correct key' do
        allow(Rails.cache).to receive(:fetch).and_call_original

        TimeMachine.now { result }

        expect(Rails.cache)
          .to have_received(:fetch)
          .with("_quota-order-numbers-#{Time.zone.today.iso8601}", expires_in: 1.day)
      end
    end
  end
end
