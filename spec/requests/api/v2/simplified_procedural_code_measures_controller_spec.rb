RSpec.describe Api::V2::SimplifiedProceduralCodeMeasuresController, :flaky, :v2 do
  describe 'GET #index' do
    before do
      create(
        :measure,
        :simplified_procedural_code,
        goods_nomenclature_item_id: '0701905000',
        validity_start_date: '2023-04-28'.to_date,
        validity_end_date: '2023-05-11'.to_date,
        simplified_procedural_code: '1.10',
        goods_nomenclature_label: 'New potatoes',
      )
      create(
        :measure,
        :simplified_procedural_code,
        goods_nomenclature_item_id: '0701905000',
        validity_start_date: '2023-04-13'.to_date,
        validity_end_date: '2023-04-27'.to_date,
        simplified_procedural_code: '1.10',
        goods_nomenclature_label: 'New potatoes',
      )
      create(
        :measure,
        :simplified_procedural_code,
        goods_nomenclature_item_id: '0708200000',
        validity_start_date: '2023-04-28'.to_date,
        validity_end_date: '2023-05-11'.to_date,
        simplified_procedural_code: '1.170',
        goods_nomenclature_label: 'Beans',
      )

      create(
        :simplified_procedural_code,
        simplified_procedural_code: '1.250.0',
        goods_nomenclature_item_id: '0709910000',
        goods_nomenclature_label: 'Globe artichokes',
      )

      get api_simplified_procedural_code_measures_path, params:
    end

    context 'when filtering by code' do
      let(:params) do
        {
          filter: {
            simplified_procedural_code: '1.10',
          },
        }
      end

      let(:pattern) do
        {
          data: [
            {
              id: '1.10',
              type: 'simplified_procedural_code_measure',
              attributes: {
                validity_start_date: '2023-04-28',
                validity_end_date: '2023-05-11',
                duty_amount: Float,
                goods_nomenclature_label: 'New potatoes',
                goods_nomenclature_item_ids: '0701905000',
                monetary_unit_code: nil,
                measurement_unit_code: 'DTN',
                measurement_unit_qualifier_code: 'R',
              },
            },
            {
              id: '1.10',
              type: 'simplified_procedural_code_measure',
              attributes: {
                validity_start_date: '2023-04-13',
                validity_end_date: '2023-04-27',
                duty_amount: Float,
                goods_nomenclature_label: 'New potatoes',
                goods_nomenclature_item_ids: '0701905000',
                monetary_unit_code: nil,
                measurement_unit_code: 'DTN',
                measurement_unit_qualifier_code: 'R',
              },
            },
          ],
        }
      end

      it { expect(response.body).to match_json_expression pattern }
    end

    context 'when filtering by from and to date' do
      let(:params) do
        {
          filter: {
            from_date: '2023-04-28',
            to_date: '2023-05-11',
          },
        }
      end

      let(:pattern) do
        {
          data: [
            {
              id: '1.10',
              type: 'simplified_procedural_code_measure',
              attributes: {
                validity_start_date: '2023-04-28',
                validity_end_date: '2023-05-11',
                duty_amount: Float,
                goods_nomenclature_label: 'New potatoes',
                goods_nomenclature_item_ids: '0701905000',
                monetary_unit_code: nil,
                measurement_unit_code: 'DTN',
                measurement_unit_qualifier_code: 'R',
              },
            },
            {
              id: '1.170',
              type: 'simplified_procedural_code_measure',
              attributes: {
                validity_start_date: '2023-04-28',
                validity_end_date: '2023-05-11',
                duty_amount: Float,
                goods_nomenclature_label: 'Beans',
                goods_nomenclature_item_ids: '0708200000',
                monetary_unit_code: nil,
                measurement_unit_code: 'DTN',
                measurement_unit_qualifier_code: 'R',
              },
            },
            {
              id: '1.250.0',
              type: 'simplified_procedural_code_measure',
              attributes: {
                validity_start_date: nil,
                validity_end_date: nil,
                duty_amount: nil,
                goods_nomenclature_label: 'Globe artichokes',
                goods_nomenclature_item_ids: '0709910000',
                monetary_unit_code: nil,
                measurement_unit_code: nil,
                measurement_unit_qualifier_code: nil,
              },
            },
          ],
        }
      end

      it { expect(response.body).to match_json_expression pattern }
    end

    describe 'when no filters are passed' do
      let(:params) { {} }

      let(:pattern) do
        {
          data: [
            {
              id: '1.10',
              type: 'simplified_procedural_code_measure',
              attributes: {
                validity_start_date: '2023-04-28',
                validity_end_date: '2023-05-11',
                duty_amount: Float,
                goods_nomenclature_label: 'New potatoes',
                goods_nomenclature_item_ids: '0701905000',
                monetary_unit_code: nil,
                measurement_unit_code: 'DTN',
                measurement_unit_qualifier_code: 'R',
              },
            },
            {
              id: '1.10',
              type: 'simplified_procedural_code_measure',
              attributes: {
                validity_start_date: '2023-04-13',
                validity_end_date: '2023-04-27',
                duty_amount: Float,
                goods_nomenclature_label: 'New potatoes',
                goods_nomenclature_item_ids: '0701905000',
                monetary_unit_code: nil,
                measurement_unit_code: 'DTN',
                measurement_unit_qualifier_code: 'R',
              },
            },
            {
              id: '1.170',
              type: 'simplified_procedural_code_measure',
              attributes: {
                validity_start_date: '2023-04-28',
                validity_end_date: '2023-05-11',
                duty_amount: Float,
                goods_nomenclature_label: 'Beans',
                goods_nomenclature_item_ids: '0708200000',
                monetary_unit_code: nil,
                measurement_unit_code: 'DTN',
                measurement_unit_qualifier_code: 'R',
              },
            },
            {
              id: '1.250.0',
              type: 'simplified_procedural_code_measure',
              attributes: {
                validity_start_date: nil,
                validity_end_date: nil,
                duty_amount: nil,
                goods_nomenclature_label: 'Globe artichokes',
                goods_nomenclature_item_ids: '0709910000',
                monetary_unit_code: nil,
                measurement_unit_code: nil,
                measurement_unit_qualifier_code: nil,
              },
            },
          ],
        }
      end

      it { expect(response.body).to match_json_expression pattern }
    end
  end
end
