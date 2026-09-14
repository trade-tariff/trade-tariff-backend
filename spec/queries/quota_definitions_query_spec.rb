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

    context 'when geographical_area_id does not exist' do
      let(:attributes) { { 'geographical_area_id' => 'UNKNOWN_AREA' } }

      it 'returns an empty result without raising' do
        expect { query.apply(Measure.actual).all }.not_to raise_error
        expect(query.apply(Measure.actual).all).to be_empty
      end
    end
  end

  describe 'status=exhausted / status=not_exhausted / status=open parity with QuotaDefinition#status' do
    subject(:query) { described_class.new(attributes, Time.zone.today) }

    let(:order_number) { create(:quota_order_number) }
    let!(:measure) do
      create(
        :measure,
        :with_goods_nomenclature,
        ordernumber: order_number.quota_order_number_id,
        validity_start_date: Time.zone.yesterday,
      )
    end
    let(:definition) do
      create(
        :quota_definition,
        quota_order_number_sid: order_number.quota_order_number_sid,
        quota_order_number_id: order_number.quota_order_number_id,
        critical_state: 'N',
        validity_start_date: Time.zone.yesterday,
      )
    end

    context 'when the quota has only a historical exhaustion event (never reopened)' do
      let(:attributes) { { 'order_number' => order_number.quota_order_number_id } }

      before do
        create(:quota_exhaustion_event, quota_definition: definition, occurrence_timestamp: 2.days.ago)
      end

      it 'reports Exhausted, matching QuotaDefinition#status' do
        expect(definition.reload.status).to eq(QuotaDefinition::STATUS_EXHAUSTED)
      end

      it 'is returned by status=exhausted' do
        query = described_class.new(attributes.merge('status' => 'exhausted'), Time.zone.today)

        expect(query.apply(Measure.actual).all).to contain_exactly(measure)
      end

      it 'is NOT returned by status=not_exhausted or status=open (regression)' do
        not_exhausted_query = described_class.new(attributes.merge('status' => 'not_exhausted'), Time.zone.today)
        open_query = described_class.new(attributes.merge('status' => 'open'), Time.zone.today)

        expect(not_exhausted_query.apply(Measure.actual).all).to be_empty
        expect(open_query.apply(Measure.actual).all).to be_empty
      end
    end

    context 'when an older exhaustion event is superseded by a newer reopening event' do
      let(:attributes) { { 'order_number' => order_number.quota_order_number_id } }

      before do
        create(:quota_exhaustion_event, quota_definition: definition, occurrence_timestamp: 2.days.ago)
        create(:quota_reopening_event, quota_definition: definition, occurrence_timestamp: 1.day.ago)
      end

      it 'reports Open, matching QuotaDefinition#status (the reopening event wins)' do
        expect(definition.reload.status).to eq(QuotaDefinition::STATUS_OPEN)
      end

      it 'is returned by status=open and status=not_exhausted, NOT status=exhausted (regression)' do
        open_query = described_class.new(attributes.merge('status' => 'open'), Time.zone.today)
        not_exhausted_query = described_class.new(attributes.merge('status' => 'not_exhausted'), Time.zone.today)
        exhausted_query = described_class.new(attributes.merge('status' => 'exhausted'), Time.zone.today)

        expect(open_query.apply(Measure.actual).all).to contain_exactly(measure)
        expect(not_exhausted_query.apply(Measure.actual).all).to contain_exactly(measure)
        expect(exhausted_query.apply(Measure.actual).all).to be_empty
      end
    end

    context 'when an older exhaustion event is superseded by a newer balance event' do
      let(:attributes) { { 'order_number' => order_number.quota_order_number_id } }

      before do
        create(:quota_exhaustion_event, quota_definition: definition, occurrence_timestamp: 2.days.ago)
        create(:quota_balance_event, quota_definition: definition, occurrence_timestamp: 1.day.ago)
      end

      it 'reports Open, matching QuotaDefinition#status (the balance event wins)' do
        expect(definition.reload.status).to eq(QuotaDefinition::STATUS_OPEN)
      end

      it 'is returned by status=open and status=not_exhausted, NOT status=exhausted (regression)' do
        open_query = described_class.new(attributes.merge('status' => 'open'), Time.zone.today)
        not_exhausted_query = described_class.new(attributes.merge('status' => 'not_exhausted'), Time.zone.today)
        exhausted_query = described_class.new(attributes.merge('status' => 'exhausted'), Time.zone.today)

        expect(open_query.apply(Measure.actual).all).to contain_exactly(measure)
        expect(not_exhausted_query.apply(Measure.actual).all).to contain_exactly(measure)
        expect(exhausted_query.apply(Measure.actual).all).to be_empty
      end
    end

    context 'when a quota is both blocked and suspended' do
      let(:attributes) { { 'order_number' => order_number.quota_order_number_id } }

      before do
        create(:quota_balance_event, quota_definition: definition, occurrence_timestamp: 3.days.ago)
        create(
          :quota_blocking_period,
          quota_definition_sid: definition.quota_definition_sid,
          blocking_start_date: 2.days.ago.to_date,
          blocking_end_date: 2.days.from_now.to_date,
        )
        create(
          :quota_suspension_period,
          quota_definition_sid: definition.quota_definition_sid,
          suspension_start_date: 1.day.ago.to_date,
          suspension_end_date: 1.day.from_now.to_date,
        )
      end

      it 'reports Suspended, and is matched by status=suspended but not status=blocked' do
        suspended_query = described_class.new(attributes.merge('status' => 'suspended'), Time.zone.today)
        blocked_query = described_class.new(attributes.merge('status' => 'blocked'), Time.zone.today)

        expect(definition.reload.status).to eq(QuotaDefinition::STATUS_SUSPENDED)
        expect(suspended_query.apply(Measure.actual).all).to contain_exactly(measure)
        expect(blocked_query.apply(Measure.actual).all).to be_empty
      end
    end

    context 'when a quota is both exhausted and blocked' do
      let(:attributes) { { 'order_number' => order_number.quota_order_number_id } }

      before do
        create(:quota_exhaustion_event, quota_definition: definition, occurrence_timestamp: 1.day.ago)
        create(
          :quota_blocking_period,
          quota_definition_sid: definition.quota_definition_sid,
          blocking_start_date: 2.days.ago.to_date,
          blocking_end_date: 2.days.from_now.to_date,
        )
      end

      it 'reports Exhausted, and is matched by status=exhausted but not status=blocked' do
        exhausted_query = described_class.new(attributes.merge('status' => 'exhausted'), Time.zone.today)
        blocked_query = described_class.new(attributes.merge('status' => 'blocked'), Time.zone.today)

        expect(definition.reload.status).to eq(QuotaDefinition::STATUS_EXHAUSTED)
        expect(exhausted_query.apply(Measure.actual).all).to contain_exactly(measure)
        expect(blocked_query.apply(Measure.actual).all).to be_empty
      end
    end

    context 'when latest event is balance and latest critical event is active' do
      let(:attributes) { { 'order_number' => order_number.quota_order_number_id } }

      before do
        create(:quota_balance_event, quota_definition: definition, occurrence_timestamp: 2.days.ago)
        create(:quota_critical_event, :active, quota_definition: definition, occurrence_timestamp: 1.day.ago)
      end

      it 'reports Critical and is excluded by status=open' do
        open_query = described_class.new(attributes.merge('status' => 'open'), Time.zone.today)

        expect(definition.reload.status).to eq(QuotaDefinition::STATUS_CRITICAL)
        expect(open_query.apply(Measure.actual).all).to be_empty
      end
    end

    context 'when query date is before a later reopening event' do
      let(:attributes) { { 'order_number' => order_number.quota_order_number_id } }
      let(:query_date) { 36.hours.ago }

      before do
        create(:quota_exhaustion_event, quota_definition: definition, occurrence_timestamp: 2.days.ago)
        create(:quota_reopening_event, quota_definition: definition, occurrence_timestamp: 1.day.ago)
      end

      it 'uses the passed date for status event cut-off' do
        exhausted_query = described_class.new(attributes.merge('status' => 'exhausted'), query_date)
        open_query = described_class.new(attributes.merge('status' => 'open'), query_date)

        expect(exhausted_query.apply(Measure.actual).all).to contain_exactly(measure)
        expect(open_query.apply(Measure.actual).all).to be_empty
      end
    end

    context 'when an exhaustion event is after the query date' do
      let(:attributes) { { 'order_number' => order_number.quota_order_number_id } }
      let(:query_date) { Time.zone.today }

      before do
        create(:quota_exhaustion_event, quota_definition: definition, occurrence_timestamp: 1.day.from_now)
      end

      it 'is ignored by status filtering (to_fragment point_in_time cutoff)' do
        exhausted_query = described_class.new(attributes.merge('status' => 'exhausted'), query_date)
        open_query = described_class.new(attributes.merge('status' => 'open'), query_date)

        expect(exhausted_query.apply(Measure.actual).all).to be_empty
        expect(open_query.apply(Measure.actual).all).to contain_exactly(measure)
      end
    end

    context 'when a suspension period starts after the query date' do
      let(:attributes) { { 'order_number' => order_number.quota_order_number_id } }
      let(:query_date) { Time.zone.today }

      before do
        create(
          :quota_suspension_period,
          quota_definition_sid: definition.quota_definition_sid,
          suspension_start_date: Date.tomorrow,
          suspension_end_date: 1.year.from_now.to_date,
        )
      end

      it 'is ignored by status filtering (to_fragment point_in_time cutoff)' do
        suspended_query = described_class.new(attributes.merge('status' => 'suspended'), query_date)
        open_query = described_class.new(attributes.merge('status' => 'open'), query_date)

        expect(suspended_query.apply(Measure.actual).all).to be_empty
        expect(open_query.apply(Measure.actual).all).to contain_exactly(measure)
      end
    end
  end
end
