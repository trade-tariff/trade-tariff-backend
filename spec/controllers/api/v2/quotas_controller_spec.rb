require 'rails_helper'

describe Api::V2::QuotasController, type: :controller do
  render_views

  describe 'quota search' do
    let(:validity_start_date) { Date.new(Date.current.year, 1, 1) }
    let(:quota_order_number) { create :quota_order_number }
    let!(:measure) { create :measure, ordernumber: quota_order_number.quota_order_number_id, validity_start_date: validity_start_date }
    let!(:quota_definition) do
      create :quota_definition,
             quota_order_number_sid: quota_order_number.quota_order_number_sid,
             quota_order_number_id: quota_order_number.quota_order_number_id,
             critical_state: 'Y',
             validity_start_date: validity_start_date
    end
    let!(:quota_order_number_origin) do
      create :quota_order_number_origin,
             :with_geographical_area,
             quota_order_number_sid: quota_order_number.quota_order_number_sid
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
              balance: nil,
              measurement_unit: nil,
              monetary_unit: String,
              measurement_unit_qualifier: String,
              last_allocation_date: nil,
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
            },
          },
          {
            id: String,
            type: 'measure',
            attributes: {
              goods_nomenclature_item_id: String,
            },
            relationships: {
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

    before do
      measure.geographical_area = quota_order_number_origin.geographical_area
      measure.save
    end

    it 'returns rendered found quotas' do
      get :search, params: { year: [Date.current.year.to_s] }, format: :json

      expect(response.body).to match_json_expression pattern
    end
  end
end
