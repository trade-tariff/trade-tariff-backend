RSpec.describe Api::V2::HeadingsController, type: :controller do
  routes { V2Api.routes }

  describe '#show' do
    subject(:do_response) { get :show, params: { id:, filter: } }

    let(:id) { heading.short_code }
    let(:filter) { {} }

    let(:heading) do
      create(
        :heading,
        :with_chapter,
        :non_grouping,
        :non_declarable,
        :with_description,
      )
    end

    before do
      allow(Rails.cache).to receive(:fetch).and_call_original
    end

    context 'when the heading is not declarable' do
      it 'calls the Rails cache with the correct key' do
        do_response

        expected_hash = Digest::MD5.hexdigest('{}')
        cache_suffix = '-v1'

        expect(Rails.cache).to have_received(:fetch).with(
          "_heading-uk-#{heading.goods_nomenclature_sid}-#{Time.zone.today.iso8601}-false-#{expected_hash}#{cache_suffix}",
          { expires_in: 24.hours },
        )
      end

      context 'when filtering by a specific geographical area' do
        let(:filter) { { geographical_area_id: 'BR' } }

        it 'calls the Rails cache with the correct key' do
          do_response

          expected_hash = Digest::MD5.hexdigest(filter.to_json)
          cache_suffix = '-v1'

          expect(Rails.cache).to have_received(:fetch).with(
            "_heading-uk-#{heading.goods_nomenclature_sid}-#{Time.zone.today.iso8601}-false-#{expected_hash}#{cache_suffix}",
            { expires_in: 24.hours },
          )
        end
      end

      context 'when the heading does not exist' do
        let(:id) { heading.short_code.next }

        it { expect(do_response).to have_http_status(:not_found) }
      end

      context 'when the heading is not declarable' do
        before { chapter }

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

        context 'when heading is present and commodity has hidden commodities' do
          let(:heading) { create(:heading, :non_declarable, :with_description) }

          let(:hidden_commodity) do
            create(
              :commodity,
              :hidden,
              :with_description,
              goods_nomenclature_item_id: "#{heading.short_code}020000",
            )
          end

          it 'does not return the hidden commodity' do
            parsed_body = JSON.parse(do_response.body)
            resources = parsed_body['included']
            commodities = resources.select { |resource| resource['type'] == 'commodity' }
            actual_commodity_codes = commodities.map { |commodity| commodity['attributes']['goods_nomenclature_item_id'] }

            expect(actual_commodity_codes).not_to include(hidden_commodity.goods_nomenclature_item_id)
          end
        end

        context 'when the record is not present' do
          let(:id) { heading.short_code.next }

          it { expect(do_response).to have_http_status(:not_found) }
        end
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
                import_trade_summary: Hash,
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
    end
  end

  describe 'GET #changes' do
    subject(:do_response) { get :changes, params: }

    let(:params) do
      {
        id: heading.short_code,
        as_of:,
      }
    end

    let(:as_of) { Time.zone.today.iso8601 }

    let(:heading) do
      create(
        :heading, :non_grouping,
        :non_declarable,
        :with_description,
        :with_chapter,
        operation_date: heading_operation_date
      )
    end

    let(:heading_operation_date) { Time.zone.today }

    context 'when changes happened after chapter creation' do
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

      it { expect(do_response.body).to match_json_expression(pattern) }
    end

    context 'when changes happened before requested date' do
      let(:heading_operation_date) { Time.zone.today }
      let(:as_of) { Time.zone.yesterday.iso8601 }

      let(:pattern) do
        {
          data: [],
          included: [],
        }
      end

      it { expect(do_response.body).to match_json_expression(pattern) }
    end

    context 'when changes include deleted record' do
      before { measure.destroy }

      let(:measure) do
        create(
          :measure,
          :with_measure_type,
          goods_nomenclature_sid: heading.goods_nomenclature_sid,
          goods_nomenclature_item_id: heading.goods_nomenclature_item_id,
          operation_date: heading_operation_date,
        )
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

      it { expect(do_response.body).to match_json_expression(pattern) }
    end
  end
end
