RSpec.describe Api::V2::AdditionalCodesController, type: :controller do
  routes { V2Api.routes }

  describe 'GET #search' do
    subject(:response) { get :search, params:, format: :json }

    let!(:additional_code) { create(:additional_code, :with_description) }

    let(:pattern) do
      {
        data: [
          {
            id: String,
            type: 'additional_code',
            attributes: {
              additional_code_type_id: String,
              additional_code: String,
              code: String,
              description: String,
              formatted_description: String,
            },
            relationships: {
              goods_nomenclatures: {
                data: [
                  {
                    id: String,
                    type: 'heading',
                  },
                ],
              },
            },
          },
        ],
        included: [
          {
            id: String,
            type: 'heading',
            attributes: {
              goods_nomenclature_item_id: String,
              description: String,
              formatted_description: String,
              producline_suffix: String,
              validity_start_date: String,
              validity_end_date: nil,
            },
          },
        ],
      }
    end

    before do
      goods_nomenclature = create(:heading)

      create(
        :measure,
        :with_base_regulation,
        additional_code:,
        goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid,
        goods_nomenclature_item_id: goods_nomenclature.goods_nomenclature_item_id,
      )
      create(
        :goods_nomenclature_description,
        goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid,
      )
      create(
        :additional_code_description,
        :with_period,
        additional_code_sid: additional_code.additional_code_sid,
      )
    end

    context 'when searching by additional code id and type' do
      let(:params) do
        {
          code: additional_code.additional_code,
          type: additional_code.additional_code_type_id,
        }
      end

      it { is_expected.to have_http_status :ok }
      it { expect(response.body).to match_json_expression pattern }
    end

    context 'when searching by additional code description' do
      let(:params) { { description: additional_code.additional_code_description.description } }

      it { is_expected.to have_http_status :ok }
      it { expect(response.body).to match_json_expression pattern }
    end

    context 'when searching by additional code id, type and description' do
      let(:params) do
        {
          code: additional_code.additional_code,
          type: additional_code.additional_code_type_id,
          description: additional_code.additional_code_description.description,
        }
      end

      it { is_expected.to have_http_status :ok }
      it { expect(response.body).to match_json_expression pattern }
    end

    context 'when searching by additional code type' do
      let(:params) { { type: additional_code.additional_code_type_id } }

      let(:pattern) do
        {
          'errors' => [
            {
              'status' => 422,
              'title' => 'is required when filtering by type',
              'detail' => 'Code is required when filtering by type',
            },
          ],
        }
      end

      it { is_expected.to have_http_status :unprocessable_entity }
      it { expect(response.body).to match_json_expression pattern }
    end

    context 'when searching by additional code id' do
      let(:params) { { code: additional_code.additional_code } }

      let(:pattern) do
        {
          'errors' => [
            {
              'status' => 422,
              'title' => 'is required when filtering by code',
              'detail' => 'Type is required when filtering by code',
            },
          ],
        }
      end

      it { is_expected.to have_http_status :unprocessable_entity }
      it { expect(response.body).to match_json_expression pattern }
    end

    context 'when searching with no params' do
      let(:params) { {} }

      let(:pattern) do
        {
          'errors' => [
            {
              'status' => 422,
              'title' => 'is required when code and type are missing',
              'detail' => 'Description is required when code and type are missing',
            },
          ],
        }
      end

      it { is_expected.to have_http_status :unprocessable_entity }
      it { expect(response.body).to match_json_expression pattern }
    end

    context 'when searching for a non-existing additional code' do
      let(:params) { { code: 'non-existing', type: 'non-existing' } }

      it { expect(response.body).to match_json_expression(data: [], included: []) }
    end
  end
end
