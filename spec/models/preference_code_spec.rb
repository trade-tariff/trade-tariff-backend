RSpec.describe PreferenceCode do
  subject(:preference_code) { described_class.new(code: '100', description: 'Erga Omnes third country duty rates') }

  it { expect(preference_code.code).to eq('100') }
  it { expect(preference_code.description).to eq('Erga Omnes third country duty rates') }

  describe '.determine_code' do
    subject { described_class.determine_code(presented_declarable, presented_measure) }

    shared_examples 'a declarable preference code determine_code operation' do
      before do
        create(
          :measure_type,
          measure_type_id: measure.measure_type_id,
          trade_movement_code: MeasureType::IMPORT_MOVEMENT_CODES.sample,
        )
      end

      let(:presented_measure) { Api::V2::Measures::MeasurePresenter.new(measure, presented_declarable) }
      let(:measures) { [measure] }
      let(:measure_collection) { MeasureCollection.new measures }

      context 'when measure_type_id does not match any conditions' do
        let(:measure) { create(:measure) }

        it { is_expected.to be_nil }
      end

      context 'when third country duty measure' do
        let(:measure) { create(:measure, measure_type_id: '103') }

        let :measure_collection do
          MeasureCollection.new measures, geographical_area_id: 'CN'
        end

        context 'when authorised_use_provisions_submission' do
          let(:measures) do
            authorised_use_provisions_submission_measure = create(
              :measure,
              :with_authorised_use_provisions_submission,
              goods_nomenclature_sid: declarable.goods_nomenclature_sid,
            )

            [measure, authorised_use_provisions_submission_measure]
          end

          it { is_expected.to eq('140') }
        end

        context 'when special_nature' do
          let(:measures) do
            special_nature_measure = create(
              :measure,
              :with_measure_conditions,
              :with_special_nature,
              goods_nomenclature_sid: declarable.goods_nomenclature_sid,
              geographical_area_id: measure.geographical_area_id,
            )

            [measure, special_nature_measure]
          end

          it { is_expected.to eq('150') }
        end

        context 'when none of above' do
          it { is_expected.to eq('100') }
        end
      end

      context 'when non preferential duty under authorised use' do
        let(:measure) { create(:measure, measure_type_id: '105') }

        it { is_expected.to eq('140') }
      end

      context 'when Customs Union Duty' do
        let(:measure) { create(:measure, measure_type_id: '106') }

        it { is_expected.to eq('400') }
      end

      context 'when autonomous tariff suspension' do
        context 'when authorised_use' do
          let(:measure) { create(:measure, :with_measure_conditions, :with_authorised_use, measure_type_id: '112') }

          it { is_expected.to eq('115') }
        end

        context 'when not authorised_use' do
          let(:measure) { create(:measure, :with_measure_conditions, measure_type_id: '112') }

          it { is_expected.to eq('110') }
        end
      end

      context 'when autonomous suspension under authorised use' do
        let(:measure) { create(:measure, measure_type_id: '115') }

        it { is_expected.to eq('115') }
      end

      context 'when suspension - goods for certain categories of ships, boats and other vessels and for drilling or production platforms' do
        let(:measure) { create(:measure, measure_type_id: '117') }

        it { is_expected.to eq('140') }
      end

      context 'when airworthiness tariff suspension' do
        let(:measure) { create(:measure, measure_type_id: '119') }

        it { is_expected.to eq('119') }
      end

      context 'when non preferential tariff quota' do
        let(:measure) { create(:measure, measure_type_id: '122') }

        context 'when special_nature' do
          let(:measures) do
            special_nature_measure = create(
              :measure,
              :with_measure_conditions,
              :with_special_nature,
              goods_nomenclature_sid: declarable.goods_nomenclature_sid,
              geographical_area_id: measure.geographical_area_id,
            )

            [measure, special_nature_measure]
          end

          it { is_expected.to eq('125') }
        end

        context 'when authorised_use' do
          let(:measure) { create(:measure, :with_measure_conditions, :with_authorised_use, measure_type_id: '122') }

          it { is_expected.to eq('123') }
        end

        context 'when none of above' do
          it { is_expected.to eq('120') }
        end
      end

      context 'when non preferential tariff quota under authorised use' do
        let(:measure) { create(:measure, measure_type_id: '123') }

        it { is_expected.to eq('123') }
      end

      context 'when preferential suspension' do
        context 'when authorised_use' do
          let(:measure) { create(:measure, :with_measure_conditions, :with_authorised_use, measure_type_id: '141') }

          it { is_expected.to eq('315') }
        end

        context 'when not authorised use' do
          let(:measure) { create(:measure, measure_type_id: '141') }

          it { is_expected.to eq('310') }
        end
      end

      context 'when tariff preference' do
        context 'when GSP and authorised_use' do
          let(:measure) { create(:measure, :with_gsp, :with_measure_conditions, :with_authorised_use, measure_type_id: '142') }

          it { is_expected.to eq('240') }
        end

        context 'when GSP' do
          let(:measure) { create(:measure, :with_gsp, measure_type_id: '142') }

          it { is_expected.to eq('200') }
        end

        context 'when authorised_use and not GSP' do
          let(:measure) { create(:measure, :with_measure_conditions, :with_authorised_use, measure_type_id: '142') }

          it { is_expected.to eq('340') }
        end

        context 'when not authorised_use or GSP' do
          let(:measure) { create(:measure, measure_type_id: '142') }

          it { is_expected.to eq('300') }
        end
      end

      context 'when preferential tariff quota' do
        context 'when GSP and special_nature' do
          let(:measure) do
            create(
              :measure,
              :with_gsp,
              :with_measure_conditions,
              :with_special_nature,
              goods_nomenclature_sid: declarable.goods_nomenclature_sid,
              measure_type_id: '143',
            )
          end

          it { is_expected.to eq('255') }
        end

        context 'when GSP and authorised_use' do
          let(:measure) do
            create(
              :measure,
              :with_gsp,
              :with_measure_conditions,
              :with_authorised_use,
              measure_type_id: '143',
            )
          end

          it { is_expected.to eq('223') }
        end

        context 'when GSP' do
          let(:measure) { create(:measure, :with_gsp, measure_type_id: '143') }

          it { is_expected.to eq('220') }
        end

        context 'when special_nature' do
          let(:measure) do
            create(
              :measure,
              :with_measure_conditions,
              :with_special_nature,
              goods_nomenclature_sid: declarable.goods_nomenclature_sid,
              measure_type_id: '143',
            )
          end

          it { is_expected.to eq('325') }
        end

        context 'when authorised_use' do
          let(:measure) { create(:measure, :with_measure_conditions, :with_authorised_use, measure_type_id: '143') }

          it { is_expected.to eq('323') }
        end

        context 'when not any of above' do
          let(:measure) { create(:measure, measure_type_id: '143') }

          it { is_expected.to eq('320') }
        end
      end

      context 'when preference under authorised use' do
        context 'when GSP' do
          let(:measure) { create(:measure, :with_gsp, measure_type_id: '145') }

          it { is_expected.to eq('240') }
        end

        context 'when not GSP' do
          let(:measure) { create(:measure, measure_type_id: '145') }

          it { is_expected.to eq('340') }
        end
      end

      context 'when preferential tariff quota under authorised use' do
        context 'when GSP' do
          let(:measure) { create(:measure, :with_gsp, measure_type_id: '146') }

          it { is_expected.to eq('223') }
        end

        context 'when not GSP' do
          let(:measure) { create(:measure, measure_type_id: '146') }

          it { is_expected.to eq('323') }
        end
      end
    end

    it_behaves_like 'a declarable preference code determine_code operation' do
      let(:presented_declarable) do
        Api::V2::Commodities::CommodityPresenter.new(declarable, measure_collection)
      end

      let(:declarable) { create(:commodity, :with_heading) }
    end

    it_behaves_like 'a declarable preference code determine_code operation' do
      let(:presented_declarable) do
        Api::V2::Headings::DeclarableHeadingPresenter.new(declarable, measure_collection)
      end

      let(:declarable) { create(:heading, :declarable) }
    end
  end

  describe 'all' do
    subject(:all) { described_class.all }

    it { expect(all.count).to eq(28) }
    it { expect(all.first).to be_a(described_class) }
  end

  describe '[]' do
    subject(:preference_code) { described_class[code] }

    context 'when the code exists' do
      let(:code) { '100' }

      it { expect(preference_code.code).to eq('100') }
      it { expect(preference_code.description).to eq('Erga Omnes third country duty rates') }
    end

    context 'when the code does not exist' do
      let(:code) { 'foo' }

      it { is_expected.to be_nil }
    end
  end
end
