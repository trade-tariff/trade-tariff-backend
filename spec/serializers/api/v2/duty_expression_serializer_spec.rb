RSpec.describe Api::V2::Measures::DutyExpressionSerializer do
  subject(:serializable_hash) { described_class.new(duty_expression).serializable_hash }

  let(:duty_expression) { create(:duty_expression) }

  describe '#serializable_hash' do
    context 'when the duty expression is generated for a commodity with the MeasurePresenter' do
      let(:duty_expression) do
        measure = create(:measure, :with_measure_components, :with_goods_nomenclature)

        Api::V2::Measures::MeasurePresenter.new(measure, measure.goods_nomenclature).duty_expression
      end

      let(:pattern) do
        {
          data: {
            id: match(/\d+-duty_expression/),
            type: eq(:duty_expression),
            attributes: {
              base: match(/- \d+.\d{2} %/),
              formatted_base: match(/- <span>\d+.\d{2}<\/span> %/),
              verbose_duty: match(/- \d+.\d{2}%/),
            },
          },
        }
      end

      it { is_expected.to include_json(pattern) }
    end

    context 'when the duty expression is generated for a heading with the Hashie::TariffMash' do
      let(:duty_expression) do
        heading = create(:heading, :non_declarable)

        create(
          :measure,
          :with_measure_type,
          :with_measure_components,
          :with_base_regulation,
          :third_country_overview,
          :with_additional_code,
          goods_nomenclature_sid: heading.commodities.first.goods_nomenclature_sid,
        )

        mash = Hashie::TariffMash.new(Cache::HeadingSerializer.new(heading).as_json)

        mash.commodities.first.overview_measures.first.duty_expression
      end

      let(:pattern) do
        {
          data: {
            id: match(/\d+-duty_expression/),
            type: eq(:duty_expression),
            attributes: {
              base: match(/- \d+.\d{2} %/),
              formatted_base: match(/- <span>\d+.\d{2}<\/span> %/),
              verbose_duty: match(/- \d+.\d{2}%/),
            },
          },
        }
      end

      it { is_expected.to include_json(pattern) }
    end
  end
end
