RSpec.describe SearchInstrumentationService do
  describe '.log_search_suggestions_results' do
    let(:query) { 'test query' }
    let(:results) do
      {
        data: [
          { type: :search_suggestion },
          { type: :search_suggestion },
          { type: :search_suggestion },
        ],
      }
    end

    before do
      allow(Rails.logger).to receive(:info)
      described_class.new(query).log_search_suggestions_results(results)
    end

    it 'logs the expected result count' do
      expect(Rails.logger).to have_received(:info).with(
        satisfy { |msg|
          begin
            JSON.parse(msg)['result_count'] == 3
          rescue StandardError
            false
          end
        },
      )
    end
  end

  describe '.log_search_results' do
    let(:test_data) do
      {
        goods_nomenclature_match: {
          'sections' => [{ '_score' => 1 }],
          'chapters' => [{ '_score' => 1 }],
          'headings' => [{ '_score' => 1 }],
          'commodities' => [{ '_score' => 1 }],
        },
        reference_match: {
          'sections' => [{ '_score' => 1.23 }],
          'chapters' => [{ '_score' => 5 }],
          'headings' => [{ '_score' => 10 }],
          'commodities' => [{ '_score' => 15 }],
        },
      }
    end

    let(:query) { 'test query' }
    let(:results) do
      {
        data: {
          type: :fuzzy_search,
          attributes: test_data,
        },
      }
    end

    before do
      allow(Rails.logger).to receive(:info)
      described_class.new(query).log_search_results(results)
    end

    it 'logs the max score correctly' do
      expect(Rails.logger).to have_received(:info).with(
        satisfy { |msg|
          begin
            JSON.parse(msg)['max_score'] == 15
          rescue StandardError
            false
          end
        },
      )
    end

    it 'logs the result count correctly' do
      expect(Rails.logger).to have_received(:info).with(
        satisfy { |msg|
          begin
            JSON.parse(msg)['result_count'] == 8
          rescue StandardError
            false
          end
        },
      )
    end

    context 'when the results type is exact_search' do
      let(:results) do
        {
          data: {
            type: :exact_search,
            attributes: test_data,
          },
        }
      end

      it 'overrides the result count to 1' do
        expect(Rails.logger).to have_received(:info).with(
          satisfy { |msg|
            begin
              JSON.parse(msg)['result_count'] == 1
            rescue StandardError
              false
            end
          },
        )
      end

      it 'logs the result zero correctly' do
        expect(Rails.logger).to have_received(:info).with(
          satisfy { |msg|
            begin
              JSON.parse(msg)['result_zero'] == false
            rescue StandardError
              false
            end
          },
        )
      end
    end
  end
end
