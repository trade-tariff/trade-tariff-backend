RSpec.describe QuotaDefinitionsQuery do
  subject(:query) { described_class.new(attributes, Time.zone.today) }

  around do |example|
    TimeMachine.now { example.run }
  end

  describe '#initialize' do
    context 'when status is not one of the allowed values' do
      let(:attributes) { { 'status' => 'not_a_real_status' } }

      it 'raises QuotaDefinitionsQuery::InvalidStatus' do
        expect { query }.to raise_error(described_class::InvalidStatus)
      end
    end

    context 'when status is valid' do
      let(:attributes) { { 'status' => 'not+exhausted' } }

      it 'unescapes the status value' do
        expect(query.status).to eq('not_exhausted')
      end
    end

    context 'when status is blank' do
      let(:attributes) { {} }

      it 'defaults to an empty status' do
        expect(query.status).to eq('')
      end
    end
  end

  describe '#apply' do
    let(:attributes) { { 'order_number' => quota_order_number.quota_order_number_id } }
    let(:quota_order_number) { create :quota_order_number }
    let(:measure) do
      create(
        :measure,
        ordernumber: quota_order_number.quota_order_number_id,
        validity_start_date: Time.zone.yesterday,
      )
    end

    before do
      measure
      create(:measure, validity_start_date: Time.zone.yesterday)
      create(
        :quota_definition,
        quota_order_number_sid: quota_order_number.quota_order_number_sid,
        quota_order_number_id: quota_order_number.quota_order_number_id,
        validity_start_date: Time.zone.yesterday,
      )
    end

    it 'is reusable against any Measure-based scope, applying the configured filters' do
      expect(query.apply(Measure.actual).all).to contain_exactly(measure)
    end
  end
end
