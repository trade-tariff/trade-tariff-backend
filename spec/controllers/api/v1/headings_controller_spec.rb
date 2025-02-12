RSpec.describe Api::V1::HeadingsController, :flaky do
  routes { V1Api.routes }

  render_views

  describe 'GET #show' do
    context 'when the heading is not declarable' do
      before do
        create(
          :chapter,
          :with_section,
          :with_description,
          goods_nomenclature_item_id: heading.chapter_id,
        )
      end

      let(:heading) do
        create :heading, :non_grouping,
               :non_declarable,
               :with_description
      end

      let(:pattern) do
        {
          goods_nomenclature_item_id: heading.code,
          description: String,
          commodities: Array,
          chapter: Hash,
          _response_info: Hash,
        }.ignore_extra_keys!
      end

      context 'when record is present' do
        it 'returns rendered record' do
          get :show, params: { id: heading }, format: :json
          expect(response.body).to match_json_expression pattern
        end
      end

      context 'when record is present and commodity has hidden commodities' do
        before do
          commodity
          hidden_commodity

          get :show, params: { id: heading }, format: :json
        end

        let(:commodity) do
          create(
            :commodity,
            :with_indent,
            :with_description,
            :with_chapter,
            :declarable,
            goods_nomenclature_item_id: "#{heading.short_code}010000",
          )
        end

        let(:hidden_commodity) do
          create(
            :commodity,
            :hidden,
            :with_indent,
            :with_description,
            :with_chapter,
            :declarable,
            goods_nomenclature_item_id: "#{heading.short_code}020000",
          )
        end

        it { expect(response.body).to include(commodity.goods_nomenclature_item_id) }
        it { expect(response.body).not_to include(hidden_commodity.goods_nomenclature_item_id) }
      end

      context 'when record is not present' do
        it 'returns not found if record was not found' do
          id = heading.goods_nomenclature_item_id.first(4).next
          get :show, params: { id: }, format: :json

          expect(response.status).to eq 404
        end
      end
    end

    context 'when the heading is declarable' do
      before do
        create(
          :chapter,
          :with_section,
          :with_description,
          goods_nomenclature_item_id: heading.chapter_id,
        )
      end

      let!(:heading) do
        create :heading, :with_indent,
               :with_description,
               :declarable
      end

      let(:pattern) do
        {
          goods_nomenclature_item_id: heading.goods_nomenclature_item_id,
          description: String,
          chapter: Hash,
          import_measures: Array,
          export_measures: Array,
          _response_info: Hash,
        }.ignore_extra_keys!
      end

      context 'when record is present' do
        it 'returns rendered record' do
          get :show, params: { id: heading }, format: :json

          expect(response.body).to match_json_expression pattern
        end
      end

      context 'when record is not present' do
        it 'returns not found if record was not found' do
          id = heading.goods_nomenclature_item_id.first(4).next
          get :show, params: { id: }, format: :json

          expect(response.status).to eq 404
        end
      end

      context 'when record is hidden' do
        let!(:heading) do
          create(
            :heading,
            :hidden,
            :with_indent,
            :with_description,
            :declarable,
          )
        end

        it 'returns not found' do
          get :show, params: { id: heading.goods_nomenclature_item_id.first(4) }, format: :json

          expect(response.status).to eq 404
        end
      end
    end
  end

  describe 'GET #changes' do
    context 'when changes happened after chapter creation' do
      let(:heading) do
        create :heading, :non_grouping,
               :non_declarable,
               :with_description,
               :with_chapter,
               operation_date: Time.zone.today
      end

      let(:pattern) do
        [
          {
            oid: Integer,
            model_name: 'Heading',
            operation: String,
            operation_date: String,
            record: {
              description: String,
              goods_nomenclature_item_id: String,
              validity_start_date: String,
              validity_end_date: nil,
            },
          },
        ].ignore_extra_values!
      end

      it 'returns heading changes' do
        get :changes, params: { id: heading }, format: :json

        expect(response.body).to match_json_expression pattern
      end
    end

    context 'when changes happened before requested date' do
      let(:heading) do
        create :heading, :non_grouping,
               :non_declarable,
               :with_description,
               :with_chapter,
               operation_date: Time.zone.today
      end

      it 'does not include change records' do
        get :changes, params: { id: heading, as_of: Time.zone.yesterday }, format: :json

        expect(response.body).to match_json_expression []
      end
    end

    context 'when changes include deleted record' do
      let(:heading) do
        create :heading, :non_grouping,
               :non_declarable,
               :with_description,
               :with_chapter,
               operation_date: Time.zone.today
      end
      let!(:measure) do
        create :measure,
               :with_measure_type,
               goods_nomenclature: heading,
               goods_nomenclature_sid: heading.goods_nomenclature_sid,
               goods_nomenclature_item_id: heading.goods_nomenclature_item_id,
               operation_date: Time.zone.today
      end
      let(:pattern) do
        [
          {
            oid: Integer,
            model_name: 'Measure',
            operation: 'D',
            record: {
              goods_nomenclature_item_id: measure.goods_nomenclature_item_id,
              measure_type: {
                description: measure.measure_type.description,
              }.ignore_extra_keys!,
            }.ignore_extra_keys!,
          }.ignore_extra_keys!,
          {
            oid: Integer,
            model_name: 'Heading',
            operation: String,
            operation_date: String,
            record: {
              description: String,
              goods_nomenclature_item_id: String,
              validity_start_date: String,
              validity_end_date: nil,
            },
          },
        ].ignore_extra_values!
      end

      before { measure.destroy }

      it 'renders record attributes' do
        get :changes, params: { id: heading }, format: :json

        expect(response.body).to match_json_expression pattern
      end
    end
  end
end
