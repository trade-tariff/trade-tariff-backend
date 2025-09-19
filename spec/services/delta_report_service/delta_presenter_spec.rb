RSpec.describe DeltaReportService::DeltaPresenter do
  let(:test_class) do
    Class.new do
      include DeltaReportService::DeltaPresenter
    end
  end

  let(:instance) { test_class.new }

  describe '#commodity_description' do
    let(:goods_nomenclature_description) { instance_double(GoodsNomenclatureDescription, csv_formatted_description: 'Formatted commodity description') }
    let(:commodity) { instance_double(Commodity, goods_nomenclature_description: goods_nomenclature_description) }

    it 'returns the csv formatted description from the commodity' do
      result = instance.commodity_description(commodity)
      expect(result).to eq('Formatted commodity description')
    end

    context 'when goods_nomenclature_description is nil' do
      let(:commodity) { instance_double(Commodity, goods_nomenclature_description: nil) }

      it 'raises an error' do
        expect { instance.commodity_description(commodity) }.to raise_error(NoMethodError)
      end
    end
  end

  describe '#footnote_description' do
    let(:footnote) { instance_double(Footnote, description: footnote_text) }

    context 'when footnote has plain text description' do
      let(:footnote_text) { 'This is a plain text footnote' }

      it 'returns the plain text unchanged' do
        result = instance.footnote_description(footnote)
        expect(result).to eq('This is a plain text footnote')
      end
    end

    context 'when footnote has HTML tags' do
      let(:footnote_text) { '<p>This is a <strong>bold</strong> footnote with <em>emphasis</em></p>' }

      it 'strips HTML tags and returns plain text' do
        result = instance.footnote_description(footnote)
        expect(result).to eq('This is a bold footnote with emphasis')
      end
    end

    context 'when footnote has complex nested HTML' do
      let(:footnote_text) { '<div><p>Nested <span class="highlight">HTML</span> content</p><ul><li>Item 1</li><li>Item 2</li></ul></div>' }

      it 'strips all HTML tags and returns clean text' do
        result = instance.footnote_description(footnote)
        expect(result).to eq('Nested HTML contentItem 1Item 2')
      end
    end

    context 'when footnote description is nil' do
      let(:footnote_text) { nil }

      it 'returns nil' do
        result = instance.footnote_description(footnote)
        expect(result).to be_nil
      end
    end

    context 'when footnote description is blank' do
      let(:footnote_text) { '' }

      it 'returns empty string' do
        result = instance.footnote_description(footnote)
        expect(result).to eq('')
      end
    end

    context 'when footnote description has only whitespace' do
      let(:footnote_text) { '   ' }

      it 'returns the whitespace unchanged (blank check fails)' do
        result = instance.footnote_description(footnote)
        expect(result).to eq('   ')
      end
    end
  end

  describe '#measure_type' do
    let(:measure_type) { instance_double(MeasureType, description: 'Third country duty') }
    let(:measure) { instance_double(Measure, measure_type: measure_type) }

    it 'returns formatted measure type with id and description' do
      result = instance.measure_type(measure)
      expect(result).to eq('Third country duty')
    end
  end

  describe '#import_export' do
    let(:measure_type) { instance_double(MeasureType) }
    let(:measure) { instance_double(Measure, measure_type: measure_type) }

    context 'when trade_movement_code is 0' do
      before { allow(measure_type).to receive(:trade_movement_code).and_return(0) }

      it 'returns Import' do
        expect(instance.import_export(measure)).to eq('Import')
      end
    end

    context 'when trade_movement_code is 1' do
      before { allow(measure_type).to receive(:trade_movement_code).and_return(1) }

      it 'returns Export' do
        expect(instance.import_export(measure)).to eq('Export')
      end
    end

    context 'when trade_movement_code is 2' do
      before { allow(measure_type).to receive(:trade_movement_code).and_return(2) }

      it 'returns Both' do
        expect(instance.import_export(measure)).to eq('Both')
      end
    end

    context 'when trade_movement_code is nil' do
      before { allow(measure_type).to receive(:trade_movement_code).and_return(nil) }

      it 'returns empty string' do
        expect(instance.import_export(measure)).to eq('')
      end
    end

    context 'when trade_movement_code is other value' do
      before { allow(measure_type).to receive(:trade_movement_code).and_return(99) }

      it 'returns empty string' do
        expect(instance.import_export(measure)).to eq('')
      end
    end

    context 'when measure_type is nil' do
      let(:measure) { instance_double(Measure, measure_type: nil) }

      it 'returns empty string' do
        expect(instance.import_export(measure)).to eq('')
      end
    end
  end

  describe '#geo_area' do
    context 'when geo_area is present' do
      let(:geo_area) { create(:geographical_area, geographical_area_id: 'EU') }

      before do
        allow(geo_area).to receive(:description).and_return('European Union')
      end

      it 'returns formatted geo area with id and description' do
        result = instance.geo_area(geo_area)
        expect(result).to eq('European Union (EU)')
      end

      context 'when geo_area is erga omnes' do
        let(:geo_area) { create(:geographical_area, :erga_omnes) }

        it 'returns "All countries" as description' do
          result = instance.geo_area(geo_area)
          expect(result).to eq('All countries (1011)')
        end
      end

      context 'when excluded_geographical_areas is provided' do
        let(:geo_area_france) { create(:geographical_area, geographical_area_id: 'FR') }
        let(:geo_area_slovakia) { create(:geographical_area, geographical_area_id: 'SK') }
        let(:excluded_geographical_areas) { [geo_area_slovakia, geo_area_france] }

        before do
          allow(geo_area_slovakia).to receive(:description).and_return('Slovakia')
          allow(geo_area_france).to receive(:description).and_return('France')
        end

        it 'includes excluded countries in the output' do
          result = instance.geo_area(geo_area, excluded_geographical_areas)
          expect(result).to eq('European Union (EU) excluding Slovakia, France')
        end
      end
    end

    context 'when geo_area is nil' do
      it 'returns empty string' do
        result = instance.geo_area(nil)
        expect(result).to eq('')
      end
    end

    context 'when geo_area is blank' do
      it 'returns empty string' do
        result = instance.geo_area('')
        expect(result).to eq('')
      end
    end
  end

  describe '#additional_code' do
    context 'when additional_code is present' do
      let(:additional_code) { build(:additional_code, :with_description, additional_code: '123') }

      it 'returns formatted additional code with code and description' do
        result = instance.additional_code(additional_code)
        expect(result).to eq("1123: #{additional_code.additional_code_description.description}")
      end
    end

    context 'when additional_code is nil' do
      it 'returns nil' do
        result = instance.additional_code(nil)
        expect(result).to be_nil
      end
    end
  end

  describe '#duty_expression' do
    context 'when there is a supplementary duty expression' do
      let(:measure) { instance_double(Measure, supplementary_unit_duty_expression: '10%', duty_expression: '10.5% + €15.25 / 100 kg') }

      it 'returns the supplementary duty expression from the measure' do
        result = instance.duty_expression(measure)
        expect(result).to eq('10%')
      end
    end

    context 'when there is no supplementary duty expression' do
      let(:measure) { instance_double(Measure, supplementary_unit_duty_expression: nil, duty_expression: '10.5% + €15.25 / 100 kg') }

      it 'returns the duty expression from the measure' do
        result = instance.duty_expression(measure)
        expect(result).to eq('10.5% + €15.25 / 100 kg')
      end
    end
  end
end
