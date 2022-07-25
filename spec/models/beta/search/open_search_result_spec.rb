RSpec.describe Beta::Search::OpenSearchResult do
  describe '.build' do
    subject(:result) { described_class.build(search_result, search_query_parser_result, goods_nomenclature_query) }

    let(:search_result) do
      fixture = file_fixture('beta/search/goods_nomenclatures/multiple_hits.json')

      Hashie::TariffMash.new(JSON.parse(fixture.read))
    end

    let(:search_query_parser_result) { build(:search_query_parser_result, :multiple_hits) }
    let(:goods_nomenclature_query) { build(:goods_nomenclature_query, :full_query) }

    it { is_expected.to be_a(described_class) }
    it { expect(result).to respond_to(:took) }
    it { expect(result.timed_out).to eq(false) }
    it { expect(result).to respond_to(:max_score) }
    it { expect(result.hits.count).to eq(10) }
    it { expect(result.search_query_parser_result).to eq(search_query_parser_result) }
    it { expect(result.goods_nomenclature_query).to eq(goods_nomenclature_query) }
  end

  describe '#id' do
    subject(:id) { build(:search_result).id }

    it { is_expected.to eq('773f19eb133e44c7b88f87902b3e557a') }
  end

  describe '#search_query_parser_result_id' do
    subject(:search_query_parser_result_id) { build(:search_result).search_query_parser_result_id }

    it { is_expected.to eq('52b14869c15726dda86b87cb93666a74') }
  end

  describe '#hit_ids' do
    subject(:hit_ids) { build(:search_result).hit_ids }

    it { is_expected.to eq([93_797, 93_796, 93_798, 93_799, 93_800, 28_100, 28_105, 93_801, 72_763, 93_994]) }
  end

  describe '#total_results' do
    subject(:total_results) { build(:search_result).total_results }

    it { is_expected.to eq(10) }
  end

  describe '#chapter_statistics' do
    context 'when statistics have been generated' do
      subject(:chapter_statistics) { build(:search_result, :generate_heading_and_chapter_statistics).chapter_statistics }

      let(:expected_chapter_statistics) do
        [
          {
            'id' => '01',
            'description' => nil,
            'score' => 485.68718800000005,
            'cnt' => 7,
            'avg' => 69.38388400000001,
          },
          {
            'id' => '02',
            'description' => nil,
            'score' => 126.686088,
            'cnt' => 2,
            'avg' => 63.343044,
          },
          {
            'id' => '03',
            'description' => nil,
            'score' => 53.984024,
            'cnt' => 1,
            'avg' => 53.984024,
          },
        ]
      end

      it { is_expected.to eq(expected_chapter_statistics) }
    end

    context 'when statistics have not been generated' do
      subject(:chapter_statistics) { build(:search_result, :no_generate_heading_and_chapter_statistics).chapter_statistics }

      it { is_expected.to be_empty }
    end
  end

  describe '#heading_statistics' do
    context 'when statistics have been generated' do
      subject(:heading_statistics) { build(:search_result, :generate_heading_and_chapter_statistics).heading_statistics }

      let(:expected_heading_statistics) do
        [
          {
            'id' => '0101',
            'description' => nil,
            'chapter_id' => '01',
            'chapter_description' => nil,
            'score' => 485.68718800000005,
            'cnt' => 7,
            'avg' => 69.38388400000001,
            'chapter_score' => 485.68718800000005,
          },
          {
            'id' => '0206',
            'description' => nil,
            'chapter_id' => '02',
            'chapter_description' => nil,
            'score' => 126.686088,
            'cnt' => 2,
            'avg' => 63.343044,
            'chapter_score' => 126.686088,
          },
          {
            'id' => '0302',
            'description' => nil,
            'chapter_id' => '03',
            'chapter_description' => nil,
            'score' => 53.984024,
            'cnt' => 1,
            'avg' => 53.984024,
            'chapter_score' => 53.984024,
          },
        ]
      end

      it { is_expected.to eq(expected_heading_statistics) }
    end

    context 'when statistics have not been generated' do
      subject(:heading_statistics) { build(:search_result, :no_generate_heading_and_chapter_statistics).heading_statistics }

      it { is_expected.to be_empty }
    end
  end

  describe '#chapter_statistic_ids' do
    context 'when there are chapter statistics' do
      subject(:chapter_statistics) { build(:search_result, :generate_heading_and_chapter_statistics).chapter_statistic_ids }

      it { is_expected.to eq(%w[01 02 03]) }
    end

    context 'when there are no chapter statistics' do
      subject(:chapter_statistics) { build(:search_result, :no_generate_heading_and_chapter_statistics).chapter_statistic_ids }

      it { is_expected.to eq(%w[]) }
    end
  end

  describe '#heading_statistic_ids' do
    context 'when there are heading statistics' do
      subject(:heading_statistics) { build(:search_result, :generate_heading_and_chapter_statistics).heading_statistic_ids }

      it { is_expected.to eq(%w[0101 0206 0302]) }
    end

    context 'when there are no heading statistics' do
      subject(:heading_statistics) { build(:search_result, :no_generate_heading_and_chapter_statistics).heading_statistic_ids }

      it { is_expected.to eq(%w[]) }
    end
  end

  describe '#guide_id' do
    subject(:guide_id) { build(:search_result, :clothing, :generate_guide_statistics).guide_id }

    it { is_expected.to eq(18) }
  end

  describe '#generate_guide_statistics' do
    subject(:search_result) { build(:search_result, :no_generate_heading_and_chapter_statistics, :clothing) }

    let(:expected_guide_statistics) do
      [
        {
          'id' => 18,
          'title' => 'Textiles and textile articles',
          'image' => 'textiles.png',
          'url' => 'https://www.gov.uk/guidance/classifying-textile-apparel',
          'strapline' => 'Get help to classify textiles and which headings and codes to use.',
          'percentage' => 100,
          'count' => 10,
        },
      ]
    end

    it 'assigns the correct statistics' do
      expect { search_result.generate_guide_statistics }
        .to change(search_result, :guide_statistics)
        .from([])
        .to(expected_guide_statistics)
    end

    it 'calls the GuideStatisticsService' do
      allow(Api::Beta::GuideStatisticsService).to receive(:new).and_call_original

      search_result.generate_guide_statistics

      expect(Api::Beta::GuideStatisticsService).to have_received(:new).with(search_result.hits)
    end
  end

  describe '#guide' do
    subject(:search_result) { build(:search_result) }

    before do
      service_double = instance_double('Api::Beta::GuideStatisticsService', call: statistics)
      allow(Api::Beta::GuideStatisticsService).to receive(:new).and_return(service_double)

      search_result.generate_guide_statistics
    end

    let(:above_threshold_guide_statistic) do
      Hashie::TariffMash.new(
        'id' => 18,
        'percentage' => 26,
      )
    end
    let(:at_threshold_guide_statistic) do
      Hashie::TariffMash.new(
        'id' => 19,
        'percentage' => 25,
      )
    end
    let(:below_threshold_guide_statistic) do
      Hashie::TariffMash.new(
        'id' => 20,
        'percentage' => 24,
      )
    end

    context 'when there are no guide statistics' do
      let(:statistics) { [] }

      it { expect(search_result.guide).to be_nil }
    end

    context 'when there are only guide statistics below or at the GUIDE_PERCENTAGE_THRESHOLD' do
      let(:statistics) do
        {
          19 => at_threshold_guide_statistic,
          20 => below_threshold_guide_statistic,
        }
      end

      it { expect(search_result.guide).to be_nil }
    end

    context 'when there is at least one guide statistic above the GUIDE_PERCENTAGE_THRESHOLD' do
      let(:statistics) do
        {
          18 => above_threshold_guide_statistic,
          19 => at_threshold_guide_statistic,
          20 => below_threshold_guide_statistic,
        }
      end

      it { expect(search_result.guide).to eq(above_threshold_guide_statistic) }
    end
  end

  describe '#redirect!' do
    subject(:result) { build(:search_result) }

    it { expect(result.redirect!).to eq(true) }
    it { expect { result.redirect! }.to change(result, :redirect?).from(nil).to(true) }
  end

  describe '#facet_filter_statistics' do
    context 'when filter statistics have been generated' do
      subject(:search_result) { build(:search_result, :generate_facet_statistics).facet_filter_statistics.map(&:id) }

      let(:expected_filter_statistic_ids) do
        %w[
          82daf4c6437dc8d7e507aa906ca5d8a1
          eccb53b0914b1e33430ac80de39c1ae5
          0ae963502c0515639087a35157e8e671
          8a34fc49e7461bf91bb00b4527081f31
        ]
      end

      it { is_expected.to eq(expected_filter_statistic_ids) }
    end

    context 'when filter statistics have not been generated' do
      subject(:search_result) { build(:search_result, :no_generate_facet_statistics).facet_filter_statistics.map(&:id) }

      it { is_expected.to eq([]) }
    end
  end
end
