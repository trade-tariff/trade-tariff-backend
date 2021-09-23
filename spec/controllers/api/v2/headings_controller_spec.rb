RSpec.describe Api::V2::HeadingsController, type: :controller do
  describe '#show' do
    subject(:do_response) { get :show, params: { id: id } }

    let(:id) { heading.goods_nomenclature_item_id.first(4) }

    let(:heading) do
      create(
        :heading,
        :non_grouping,
        :non_declarable,
        :with_description,
      )
    end

    context 'when the heading short code does not exist' do
      let(:id) { heading.goods_nomenclature_item_id.first(4) + 1 }

      it { expect(do_response).to have_http_status(:not_found) }
    end

    context 'when the heading is not declarable' do
      let(:heading) do
        create(
          :heading,
          :non_grouping,
          :non_declarable,
          :with_description,
        )
      end

      let(:chapter) do
        create(
          :chapter,
          :with_section, :with_description,
          goods_nomenclature_item_id: heading.chapter_id
        )
      end

      context 'when record is present' do
        let(:pattern) do
          {
            data: {
              id: String,
              type: String,
              attributes: {
                goods_nomenclature_item_id: heading.code,
                description: String,
              }.ignore_extra_keys!,
              relationships: {
                commodities: Hash,
                chapter: Hash,
              }.ignore_extra_keys!,
            }.ignore_extra_keys!,
          }.ignore_extra_keys!
        end

        it { expect(do_response.body).to match_json_expression(pattern) }
      end

      #  context 'when heading is present and commodity has hidden commodities' do
      #    let(:unhidden_commodity) { create :commodity, :with_description, goods_nomenclature_item_id: "#{heading.short_code}010000" }
      #    let(:hidden_commodity) { create :commodity, :with_description, goods_nomenclature_item_id: "#{heading.short_code}020000" }
      #    let(:hidden_goods_nomenclature) { create :hidden_goods_nomenclature, goods_nomenclature_item_id: hidden_commodity.goods_nomenclature_item_id }

      #    let(:included_commodity_sids) do
      #      parsed_body = JSON.parse(do_response.body)
      #      resources = parsed_body['included']
      #      commodities = resources.select { |resource| resource['type'] == 'commodity' }
      #      commodities.map { |commodity| commodity['attributes']['goods_nomenclature_sid'] }
      #    end

      #    before do
      #      unhidden_commodity
      #      hidden_commodity
      #      hidden_goods_nomenclature
      #    end

      #    it 'returns only the unhidden commodity' do
      #      expect(included_commodity_sids).to eq([unhidden_commodity.goods_nomenclature_sid])
      #    end
      #  end

      context 'when the record is not present' do
        let(:id) { heading.goods_nomenclature_item_id.first(4).to_i + 1 }

        it { expect(do_response).to have_http_status(:not_found) }
      end
    end

    context 'when the heading is declarable' do
      let(:heading) do
        create(
          :heading,
          :with_indent,
          :with_description,
          :declarable,
          :with_chapter,
        )
      end

      context 'when record is present' do
        let(:pattern) do
          {
            data: {
              id: String,
              type: 'heading',
              attributes: {
                goods_nomenclature_item_id: heading.goods_nomenclature_item_id,
                description: String,
              }.ignore_extra_keys!,
              relationships: {
                chapter: Hash,
                import_measures: Hash,
                export_measures: Hash,
                footnotes: Hash,
                section: Hash,
              },
              meta: {
                duty_calculator: {
                  applicable_additional_codes: Hash,
                  applicable_measure_units: Hash,
                  applicable_vat_options: Hash,
                  entry_price_system: false,
                  meursing_code: false,
                  source: 'uk',
                  trade_defence: false,
                  zero_mfn_duty: false,
                },
              },
            },
          }.ignore_extra_keys!
        end

        it { expect(do_response.body).to match_json_expression(pattern) }
      end

      context 'when record is hidden' do
        let!(:hidden_goods_nomenclature) { create :hidden_goods_nomenclature, goods_nomenclature_item_id: heading.goods_nomenclature_item_id }
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
               operation_date: Date.current
      end

      let(:pattern) do
        {
          data: [
            {
              id: String,
              type: 'change',
              attributes: {
                oid: Integer,
                model_name: 'Heading',
                operation: 'C',
                operation_date: String,
              },
              relationships: {
                record: {
                  data: {
                    id: String,
                    type: 'heading',
                  },
                },
              },
            },
          ],
          included: [
            {
              id: String,
              type: 'heading',
              attributes: {
                description: String,
                goods_nomenclature_item_id: String,
                validity_start_date: String,
                validity_end_date: nil,
              },
            },
          ],
        }
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
               operation_date: Date.current
      end

      let!(:pattern) do
        {
          data: [],
          included: [],
        }
      end

      it 'does not include change records' do
        get :changes, params: { id: heading, as_of: Date.yesterday }, format: :json

        expect(response.body).to match_json_expression pattern
      end
    end

    context 'when changes include deleted record' do
      let(:heading) do
        create :heading, :non_grouping,
               :non_declarable,
               :with_description,
               :with_chapter,
               operation_date: Date.current
      end
      let!(:measure) do
        create :measure,
               :with_measure_type,
               goods_nomenclature: heading,
               goods_nomenclature_sid: heading.goods_nomenclature_sid,
               goods_nomenclature_item_id: heading.goods_nomenclature_item_id,
               operation_date: Date.current
      end
      let(:pattern) do
        {
          data: [
            {
              id: String,
              type: 'change',
              attributes: {
                oid: Integer,
                model_name: 'Measure',
                operation: 'C',
                operation_date: String,
              },
              relationships: {
                record: {
                  data: {
                    id: String,
                    type: 'measure',
                  },
                },
              },
            },
            {
              id: String,
              type: 'change',
              attributes: {
                oid: Integer,
                model_name: 'Measure',
                operation: 'D',
                operation_date: String,
              },
              relationships: {
                record: {
                  data: {
                    id: String,
                    type: 'measure',
                  },
                },
              },
            },
            {
              id: String,
              type: 'change',
              attributes: {
                oid: Integer,
                model_name: 'Heading',
                operation: 'C',
                operation_date: String,
              },
              relationships: {
                record: {
                  data: {
                    id: String,
                    type: 'heading',
                  },
                },
              },
            },
          ],
          included: [
            {
              id: String,
              type: 'measure',
              attributes: Hash,
              relationships: {
                geographical_area: Hash,
                measure_type: Hash,
              },
            },
            {
              id: String,
              type: 'geographical_area',
              attributes: Hash,
            },
            {
              id: String,
              type: 'measure_type',
              attributes: Hash,
            },
            {
              id: String,
              type: 'heading',
              attributes: Hash,
            },
          ],
        }
      end

      before { measure.destroy }

      it 'renders record attributes' do
        get :changes, params: { id: heading }, format: :json

        expect(response.body).to match_json_expression pattern
      end
    end
  end
end
