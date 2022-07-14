require 'rails_helper'

RSpec.describe Beta::Search::OpenSearchResult do
  describe '.build' do
    subject(:result) { described_class.build(search_result, search_query_parser_result) }

    let(:search_result) do
      fixture = file_fixture('beta/search/goods_nomenclatures/multiple_hits.json')

      Hashie::TariffMash.new(JSON.parse(fixture.read))
    end

    let(:search_query_parser_result) { build(:search_query_parser_result, :multiple_hits) }

    it { is_expected.to be_a(described_class) }
    it { expect(result.took).to eq(3) }
    it { expect(result.timed_out).to eq(false) }
    it { expect(result.max_score).to eq(161.34302) }
    it { expect(result.hits.count).to eq(10) }
    it { expect(result.search_query_parser_result).to eq(search_query_parser_result) }
  end

  describe '#id' do
    subject(:id) { build(:search_result).id }

    it { is_expected.to eq('40d70a67aafa270656c01738cfec041b') }
  end

  describe '#search_query_parser_result_id' do
    subject(:search_query_parser_result_id) { build(:search_result).search_query_parser_result_id }

    it { is_expected.to eq('52b14869c15726dda86b87cb93666a74') }
  end

  describe '#hit_ids' do
    subject(:hit_ids) { build(:search_result).hit_ids }

    it { is_expected.to eq([93_797, 93_796, 93_798, 93_799, 93_800, 93_801, 72_763, 27_624, 93_994, 95_674]) }
  end

  describe '#total_results' do
    subject(:total_results) { build(:search_result).total_results }

    it { is_expected.to eq(10) }
  end

  describe '#chapter_statistics' do
    context 'when statistics have been generated' do
      subject(:chapter_statistics) { build(:search_result, :generate_statistics).chapter_statistics }

      let(:expected_chapter_statistics) do
        [
          {
            'id' => '01',
            'description' => 'LIVE ANIMALS',
            'score' => 1133.32071,
            'cnt' => 8,
            'avg' => 141.66508875,
          },
          {
            'id' => '03',
            'description' => 'FISH AND CRUSTACEANS, MOLLUSCS AND OTHER AQUATIC INVERTEBRATES',
            'score' => 138.529,
            'cnt' => 2,
            'avg' => 69.2645,
          },
        ]
      end

      it { is_expected.to eq(expected_chapter_statistics) }
    end

    context 'when statistics have not been generated' do
      subject(:chapter_statistics) { build(:search_result, :no_generate_statistics).chapter_statistics }

      it { is_expected.to be_empty }
    end
  end

  describe '#heading_statistics' do
    context 'when statistics have been generated' do
      subject(:heading_statistics) { build(:search_result, :generate_statistics).heading_statistics }

      let(:expected_heading_statistics) do
        [
          {
            'id' => '0101',
            'description' => 'Live horses, asses, mules and hinnies',
            'chapter_id' => '01',
            'chapter_description' => 'LIVE ANIMALS',
            'score' => 1133.32071,
            'cnt' => 8,
            'avg' => 141.66508875,
            'chapter_score' => 1133.32071,
          },
          {
            'id' => '0302',
            'description' => 'Fish, fresh or chilled, excluding fish fillets and other fish meat of heading 0304',
            'chapter_id' => '03',
            'chapter_description' => 'FISH AND CRUSTACEANS, MOLLUSCS AND OTHER AQUATIC INVERTEBRATES',
            'score' => 138.529,
            'cnt' => 2,
            'avg' => 69.2645,
            'chapter_score' => 138.529,
          },
        ]
      end

      it { is_expected.to eq(expected_heading_statistics) }
    end

    context 'when statistics have not been generated' do
      subject(:heading_statistics) { build(:search_result, :no_generate_statistics).heading_statistics }

      it { is_expected.to be_empty }
    end
  end

  describe '#chapter_statistic_ids' do
    context 'when there are chapter statistics' do
      subject(:chapter_statistics) { build(:search_result, :generate_statistics).chapter_statistic_ids }

      it { is_expected.to eq(%w[01 03]) }
    end

    context 'when there are no chapter statistics' do
      subject(:chapter_statistics) { build(:search_result, :no_generate_statistics).chapter_statistic_ids }

      it { is_expected.to eq(%w[]) }
    end
  end

  describe '#heading_statistic_ids' do
    context 'when there are heading statistics' do
      subject(:heading_statistics) { build(:search_result, :generate_statistics).heading_statistic_ids }

      it { is_expected.to eq(%w[0101 0302]) }
    end

    context 'when there are no heading statistics' do
      subject(:heading_statistics) { build(:search_result, :no_generate_statistics).heading_statistic_ids }

      it { is_expected.to eq(%w[]) }
    end
  end
end
