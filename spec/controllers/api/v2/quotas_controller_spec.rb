RSpec.describe Api::V2::QuotasController, type: :controller do
  routes { V2Api.routes }

  describe 'GET /quotas/search.json' do
    let(:validity_start_date) { Date.new(Time.zone.today.year, 1, 1) }
    let(:quota_order_number) { create :quota_order_number }
    let!(:measure) do
      create(
        :measure,
        ordernumber: quota_order_number.quota_order_number_id,
        validity_start_date:,
        goods_nomenclature:,
      )
    end
    let(:goods_nomenclature) { create(:commodity, :with_heading, :declarable) }

    before do
      create(:quota_definition, :with_quota_balance_events,
             quota_order_number_sid: quota_order_number.quota_order_number_sid,
             quota_order_number_id: quota_order_number.quota_order_number_id,
             critical_state: 'Y',
             validity_start_date:)

      quota_order_number_origin = create(:quota_order_number_origin, :with_geographical_area, :with_quota_order_number_origin_exclusion,
                                         quota_order_number_sid: quota_order_number.quota_order_number_sid)

      measure.update(geographical_area: quota_order_number_origin.geographical_area)
      GeographicalArea.refresh!
    end

    context 'when not specifying an includes list in the query params' do
      let(:params) { { year: [Time.zone.today.year.to_s] } }

      let(:pattern) do
        {
          data: [
            {
              id: String,
              type: 'definition',
              attributes: {
                quota_definition_sid: Integer,
                quota_order_number_id: String,
                initial_volume: nil,
                validity_start_date: String,
                validity_end_date: nil,
                status: String,
                description: nil,
                balance: String,
                measurement_unit: nil,
                monetary_unit: String,
                measurement_unit_qualifier: String,
                last_allocation_date: String,
                suspension_period_start_date: nil,
                suspension_period_end_date: nil,
                blocking_period_start_date: nil,
                blocking_period_end_date: nil,
              },
              relationships: {
                order_number: {
                  data: {
                    id: String,
                    type: 'order_number',
                  },
                },
                measures: {
                  data: [
                    {
                      id: String,
                      type: 'measure',
                    },
                  ],
                },
                quota_balance_events: {},
                incoming_quota_closed_and_transferred_event: { data: nil },
                quota_order_number_origins: { data: [{ id: String, type: 'quota_order_number_origin' }] },
              },
            },
          ],
          included: [
            {
              id: String,
              type: 'order_number',
              attributes: {
                number: String,
              },
              relationships: {
                geographical_areas: {
                  data: [
                    {
                      id: String,
                      type: 'geographical_area',
                    },
                  ],
                },
              },
            },
            {
              id: String,
              type: 'geographical_area',
              attributes: {
                id: String,
                description: String,
                geographical_area_id: String,
                geographical_area_sid: Integer,
              },
            },
            {
              id: String,
              type: 'measure',
              attributes: {
                goods_nomenclature_item_id: String,
                validity_start_date: String,
                validity_end_date: nil,
              },
              relationships: {
                geographical_area: {
                  data: {
                    id: String,
                    type: 'geographical_area',
                  },
                },
                goods_nomenclature: {
                  data: {
                    id: String,
                    type: 'commodity',
                  },
                },
              },
            },
            {
              id: String,
              type: 'commodity',
              attributes: {
                goods_nomenclature_item_id: String,
                producline_suffix: String,
                description: String,
                formatted_description: nil,
                validity_start_date: String,
                validity_end_date: nil,
              },
            },
            {
              id: String,
              type: 'geographical_area',
              attributes: {
                id: String,
                description: String,
                geographical_area_id: String,
                geographical_area_sid: Integer,
              },
            },
            {
              id: String,
              type: 'quota_order_number_origin_exclusion',
              relationships: {
                geographical_area: {
                  data: { id: String, type: 'geographical_area' },
                },
              },
            },
            {
              id: String,
              type: 'quota_order_number_origin',
              attributes: {
                validity_start_date: String,
                validity_end_date: nil,
              },
              relationships: {
                quota_order_number_origin_exclusions: { data: [{ id: String, type: 'quota_order_number_origin_exclusion' }] },
                geographical_area: {
                  data: {
                    id: String,
                    type: 'geographical_area',
                  },
                },
              },
            },
          ],
          meta: {
            pagination: {
              page: Integer,
              per_page: Integer,
              total_count: Integer,
            },
          },
        }
      end

      it 'returns rendered found quotas' do
        get :search, params:, format: :json

        expect(response.body).to match_json_expression pattern
      end
    end

    context 'when specifying an includes list in the query params' do
      let(:params) do
        {
          year: [
            Time.zone.today.year.to_s,
          ],
          include: include_param,
        }
      end

      let(:pattern) do
        {
          data: [
            {
              id: String,
              type: 'definition',
              attributes: {
                quota_definition_sid: Integer,
                quota_order_number_id: String,
                initial_volume: nil,
                validity_start_date: String,
                validity_end_date: nil,
                status: String,
                description: nil,
                balance: String,
                measurement_unit: nil,
                monetary_unit: String,
                measurement_unit_qualifier: String,
                last_allocation_date: String,
                suspension_period_start_date: nil,
                suspension_period_end_date: nil,
                blocking_period_start_date: nil,
                blocking_period_end_date: nil,
              },
              relationships: {
                quota_balance_events: {
                  data: [
                    {
                      id: String,
                      type: 'quota_balance_event',
                    },
                  ],
                },
                order_number: {},
                measures: {},
                incoming_quota_closed_and_transferred_event: { data: nil },
                quota_order_number_origins: {},
              },
            },
          ],
          included: [
            {
              id: String,
              type: 'quota_balance_event',
              attributes: {
                quota_definition_sid: Integer,
                occurrence_timestamp: String,
                last_import_date_in_allocation: String,
                old_balance: String,
                new_balance: String,
                imported_amount: String,
              },
            },
          ],
          meta: {
            pagination: {
              page: Integer,
              per_page: Integer,
              total_count: Integer,
            },
          },
        }
      end

      context 'when included resources are valid' do
        let(:include_param) { 'quota_balance_events' }

        it 'returns rendered found quotas with the allowed resources' do
          get :search, params:, format: :json

          expect(response.body).to match_json_expression pattern
        end
      end

      context 'when included resources are NOT allowed (or non-existent)' do
        let(:include_param) { 'wrong_resource' }

        it 'raises an ArgumentError' do
          expect {
            get :search, params:, format: :json
          }.to raise_error(ArgumentError, /wrong_resource/)
        end
      end
    end
  end
end
