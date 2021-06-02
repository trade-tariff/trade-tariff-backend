require 'rails_helper'

describe QuotaSearchService do
  describe 'quota search' do
    around do |example|
      TimeMachine.now { example.run }
    end

    let(:validity_start_date) { Date.new(Date.current.year, 1, 1) }
    let(:quota_order_number1) { create :quota_order_number }
    let!(:measure1) { create :measure, ordernumber: quota_order_number1.quota_order_number_id, validity_start_date: validity_start_date }
    let!(:quota_definition1) do
      create :quota_definition,
             quota_order_number_sid: quota_order_number1.quota_order_number_sid,
             quota_order_number_id: quota_order_number1.quota_order_number_id,
             critical_state: 'Y',
             validity_start_date: validity_start_date
    end
    let!(:quota_order_number_origin1) do
      create :quota_order_number_origin,
             :with_geographical_area,
             quota_order_number_sid: quota_order_number1.quota_order_number_sid
    end

    let(:quota_order_number2) { create :quota_order_number }
    let!(:measure2) { create :measure, ordernumber: quota_order_number2.quota_order_number_id, validity_start_date: validity_start_date }
    let!(:quota_definition2) do
      create :quota_definition,
             quota_order_number_sid: quota_order_number2.quota_order_number_sid,
             quota_order_number_id: quota_order_number2.quota_order_number_id,
             critical_state: 'N',
             validity_start_date: validity_start_date
    end
    let!(:quota_order_number_origin2) do
      create :quota_order_number_origin,
             :with_geographical_area,
             quota_order_number_sid: quota_order_number2.quota_order_number_sid
    end
    let(:current_page) { 1 }
    let(:per_page) { 20 }

    before do
      measure1.update(geographical_area_id: quota_order_number_origin1.geographical_area_id)
      measure2.update(geographical_area_id: quota_order_number_origin2.geographical_area_id)
    end

    describe '#status' do
      subject(:service) do
        described_class.new(
          {
            'status' => status,
            'year' => Date.current.year.to_s,
          },
          current_page,
          per_page,
        )
      end

      context 'when the status is url encoded' do
        let(:status) { 'not+exhausted' }

        it 'unescapes status values' do
          expect(service.status).to eq('not_exhausted')
        end
      end
    end

    context 'by goods_nomenclature_item_id' do
      it 'finds quota definition by goods nomenclature' do
        result = described_class.new(
          {
            'goods_nomenclature_item_id' => measure1.goods_nomenclature_item_id,
            'year' => Date.current.year.to_s,
          }, current_page, per_page
        ).perform
        expect(result).to include(quota_definition1)
      end

      it 'does not find quota definition by wrong goods nomenclature' do
        result = described_class.new(
          {
            'goods_nomenclature_item_id' => measure1.goods_nomenclature_item_id,
            'year' => Date.current.year.to_s,
          }, current_page, per_page
        ).perform
        expect(result).not_to include(quota_definition2)
      end
    end

    context 'by geographical_area_id' do
      it 'finds quota definition by geographical area' do
        result = described_class.new(
          {
            'geographical_area_id' => quota_order_number_origin1.geographical_area_id,
            'year' => Date.current.year.to_s,
          }, current_page, per_page
        ).perform
        expect(result).to include(quota_definition1)
      end

      it 'does not find quota definition by wrong geographical area' do
        result = described_class.new(
          {
            'geographical_area_id' => quota_order_number_origin1.geographical_area_id,
            'year' => Date.current.year.to_s,
          }, current_page, per_page
        ).perform
        expect(result).not_to include(quota_definition2)
      end
    end

    context 'by order_number' do
      it 'finds quota definition by order number' do
        result = described_class.new(
          {
            'order_number' => quota_order_number1.quota_order_number_id,
            'year' => Date.current.year.to_s,
          }, current_page, per_page
        ).perform
        expect(result).to include(quota_definition1)
      end

      it 'does not find quota definition by wrong order number' do
        result = described_class.new(
          {
            'order_number' => quota_order_number1.quota_order_number_id,
            'year' => Date.current.year.to_s,
          }, current_page, per_page
        ).perform
        expect(result).not_to include(quota_definition2)
      end
    end

    context 'by critical' do
      it 'finds quota definition by critical state' do
        result = described_class.new(
          {
            'critical' => quota_definition1.critical_state,
            'year' => Date.current.year.to_s,
          }, current_page, per_page
        ).perform
        expect(result).to include(quota_definition1)
      end

      it 'does not find quota definition by wrong critical state' do
        result = described_class.new(
          {
            'critical' => quota_definition1.critical_state,
            'year' => Date.current.year.to_s,
          }, current_page, per_page
        ).perform
        expect(result).not_to include(quota_definition2)
      end
    end

    context 'by years' do
      let(:past_validity_start_date) { Date.new(Date.current.year - 1, 1, 1) }
      let(:quota_order_number3) { create :quota_order_number }
      let!(:measure3) { create :measure, ordernumber: quota_order_number3.quota_order_number_id, validity_start_date: past_validity_start_date }
      let!(:quota_definition3) do
        create :quota_definition,
               quota_order_number_sid: quota_order_number3.quota_order_number_sid,
               quota_order_number_id: quota_order_number3.quota_order_number_id,
               critical_state: 'N',
               validity_start_date: past_validity_start_date
      end
      let!(:quota_order_number_origin3) do
        create :quota_order_number_origin,
               :with_geographical_area,
               quota_order_number_sid: quota_order_number3.quota_order_number_sid
      end

      it 'finds quota definition by year' do
        result = described_class.new(
          {
            'years' => Date.current.year.to_s,
          }, current_page, per_page
        ).perform
        expect(result).to include(quota_definition1)
      end

      it 'finds quota definition by multiple years' do
        result = described_class.new(
          {
            'years' => [Date.current.year.to_s, (Date.current.year - 1).to_s],
          }, current_page, per_page
        ).perform
        expect(result).to include(quota_definition1)
        expect(result).to include(quota_definition3)
      end

      it 'does not find quota definition by wrong year' do
        result = described_class.new(
          {
            'years' => Date.current.year.to_s,
          }, current_page, per_page
        ).perform
        expect(result).not_to include(quota_definition3)
      end
    end

    context 'by date' do
      let(:past_validity_start_date) { Date.new(Date.current.year - 1, 1, 1) }
      let(:quota_order_number3) { create :quota_order_number }
      let!(:measure3) { create :measure, ordernumber: quota_order_number3.quota_order_number_id, validity_start_date: past_validity_start_date }
      let!(:quota_definition3) do
        create :quota_definition,
               quota_order_number_sid: quota_order_number3.quota_order_number_sid,
               quota_order_number_id: quota_order_number3.quota_order_number_id,
               critical_state: 'N',
               validity_start_date: past_validity_start_date
      end
      let!(:quota_order_number_origin3) do
        create :quota_order_number_origin,
               :with_geographical_area,
               quota_order_number_sid: quota_order_number3.quota_order_number_sid
      end

      it 'finds quota definition by year only' do
        result = described_class.new(
          {
            'year' => (Date.current.year - 1).to_s,
          }, current_page, per_page
        ).perform
        expect(result).not_to include(quota_definition1)
      end

      it 'doesn\'t filter quota definition by month only' do
        result = described_class.new(
          {
            'month' => Date.current.month.to_s,
          }, current_page, per_page
        ).perform
        expect(result).to include(quota_definition1, quota_definition2, quota_definition3)
      end

      it 'doesn\'t filter quota definition by day only' do
        result = described_class.new(
          {
            'day' => Date.current.day.to_s,
          }, current_page, per_page
        ).perform
        expect(result).to include(quota_definition1, quota_definition2, quota_definition3)
      end

      it 'finds quota definition by full date' do
        result = described_class.new(
          {
            'year' => Date.current.year.to_s,
            'month' => Date.current.month.to_s,
            'day' => Date.current.day.to_s,
          }, current_page, per_page
        ).perform
        expect(result).to include(quota_definition1, quota_definition2, quota_definition3)
      end

      it 'does not find quota definition by wrong date' do
        result = described_class.new(
          {
            'year' => (Date.current.year - 1).to_s,
            'month' => Date.current.month.to_s,
            'day' => Date.current.day.to_s,
          }, current_page, per_page
        ).perform
        expect(result).not_to include(quota_definition1)
      end
    end

    context 'by status' do
      context 'exhausted' do
        let!(:quota_exhaustion_event) do
          create :quota_exhaustion_event,
                 quota_definition: quota_definition1
        end

        it 'finds quota definition by exhausted status' do
          result = described_class.new(
            {
              'status' => 'exhausted',
              'year' => Date.current.year.to_s,
            }, current_page, per_page
          ).perform
          expect(result).to include(quota_definition1)
        end

        it 'does not find quota definition by wrong exhausted status' do
          result = described_class.new(
            {
              'status' => 'exhausted',
              'year' => Date.current.year.to_s,
            }, current_page, per_page
          ).perform
          expect(result).not_to include(quota_definition2)
        end
      end

      context 'not exhausted' do
        let!(:quota_exhaustion_event) do
          create :quota_exhaustion_event,
                 quota_definition: quota_definition1
        end

        it 'finds quota definition by not exhausted status' do
          result = described_class.new(
            {
              'status' => 'not_exhausted',
              'year' => Date.current.year.to_s,
            }, current_page, per_page
          ).perform
          expect(result).to include(quota_definition2)
        end

        it 'does not find quota definition by wrong not exhausted status' do
          result = described_class.new(
            {
              'status' => 'not_exhausted',
              'year' => Date.current.year.to_s,
            }, current_page, per_page
          ).perform
          expect(result).not_to include(quota_definition1)
        end
      end

      context 'blocked' do
        let!(:quota_blocking_period) do
          create :quota_blocking_period,
                 quota_definition_sid: quota_definition1.quota_definition_sid,
                 blocking_start_date: Date.current,
                 blocking_end_date: 1.year.from_now
        end

        it 'finds quota definition by blocked status' do
          result = described_class.new(
            {
              'status' => 'blocked',
              'year' => Date.current.year.to_s,
            }, current_page, per_page
          ).perform
          expect(result).to include(quota_definition1)
        end

        it 'does not find quota definition by wrong blocked status' do
          result = described_class.new(
            {
              'status' => 'blocked',
              'year' => Date.current.year.to_s,
            }, current_page, per_page
          ).perform
          expect(result).not_to include(quota_definition2)
        end
      end

      context 'not blocked' do
        let!(:quota_blocking_period) do
          create :quota_blocking_period,
                 quota_definition_sid: quota_definition1.quota_definition_sid,
                 blocking_start_date: Date.current,
                 blocking_end_date: 1.year.from_now
        end

        it 'finds quota definition by not blocked status' do
          result = described_class.new(
            {
              'status' => 'not_blocked',
              'year' => Date.current.year.to_s,
            }, current_page, per_page
          ).perform
          expect(result).to include(quota_definition2)
        end

        it 'finds quota definition by not blocked status with encoded values' do
          result = described_class.new(
            {
              'status' => 'not+blocked',
              'year' => Date.current.year.to_s,
            }, current_page, per_page
          ).perform
          expect(result).to include(quota_definition2)
          result = described_class.new(
            {
              'status' => 'not%2bblocked',
              'year' => Date.current.year.to_s,
            }, current_page, per_page
          ).perform
          expect(result).to include(quota_definition2)
        end

        it 'does not find quota definition by wrong not blocked status' do
          result = described_class.new(
            {
              'status' => 'not_blocked',
              'year' => Date.current.year.to_s,
            }, current_page, per_page
          ).perform
          expect(result).not_to include(quota_definition1)
        end
      end

      context '094 quotas' do
        let!(:measure_094) do
          create :measure,
                 ordernumber: "094#{3.times.map { Random.rand(9) }.join}",
                 validity_start_date: validity_start_date
        end
        let!(:quota_order_number_094) { create :quota_order_number, quota_order_number_id: measure_094.ordernumber }
        let!(:quota_definition_094) do
          create :quota_definition,
                 quota_order_number_sid: quota_order_number_094.quota_order_number_sid,
                 quota_order_number_id: quota_order_number_094.quota_order_number_id,
                 critical_state: 'Y',
                 validity_start_date: validity_start_date
        end

        it 'searches 094 quotas' do
          result = described_class.new(
            {
              'order_number' => measure_094.ordernumber,
              'year' => Date.current.year.to_s,
            }, current_page, per_page
          ).perform
          expect(result.first.quota_order_number_id).to eq(measure_094.ordernumber)
        end
      end
    end
  end
end
