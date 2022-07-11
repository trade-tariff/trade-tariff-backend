require 'rails_helper'

RSpec.describe Beta::Search::SearchResult do
  describe '.build' do
    subject(:result) { described_class.build(search_result, search_query_parser_result) }

    let(:search_result) do
      test_filename = Rails.root.join(file_fixture_path, 'beta/search/goods_nomenclatures/multiple_hits.json')

      Hashie::TariffMash.new(JSON.parse(File.read(test_filename)))
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
end
