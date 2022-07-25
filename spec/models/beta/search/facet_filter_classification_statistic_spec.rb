RSpec.describe Beta::Search::FacetFilterClassificationStatistic do
  describe '#facet' do
    subject(:facet) { build(:search_result, :generate_facet_statistics).facet_filter_statistics.first.facet }

    it { is_expected.to eq('animal_type') }
  end

  describe '.build' do
    subject(:facet_filter_statistic) { described_class.build(statistic) }

    let(:statistic) do
      {
        'classifications' => {
          'equine animals' => {
            'count' => 10,
            'filter_facet' => 'filter_animal_type',
            'classification' => 'equine animals',
          },
          'fish' => {
            'count' => 1,
            'filter_facet' => 'filter_animal_type',
            'classification' => 'fish',
          },
        },
        'count' => 10,
        'filter_facet' => 'filter_animal_type',
      }
    end

    it { is_expected.to be_a(described_class) }
    it { expect(facet_filter_statistic.facet_filter).to eq('filter_animal_type') }
    it { expect(facet_filter_statistic.facet_count).to eq(10) }
    it { expect(facet_filter_statistic.facet_classification_statistic_ids).to eq(%w[3afc6150b5c9a06ba76a427bf50d4efb a20f3c40ef03c710ed7d5eb87a81a0ea]) }
    it { expect(facet_filter_statistic.facet_classification_statistics).to be_many }
    it { expect(facet_filter_statistic.display_name).to eq('Animal type') }
    it { expect(facet_filter_statistic.question).to eq('What type of animal?') }
    it { expect(facet_filter_statistic.boost).to eq(1) }
  end

  describe '.display_name_for' do
    subject(:display_name_for) { described_class.display_name_for(facet) }

    context 'when the facet has a display name in the facet settings file' do
      let(:facet) { 'animal_product_state' }

      it { is_expected.to eq('Animal state') }
    end

    context 'when the facet does not have a display name in the facet settings file' do
      let(:facet) { 'some_category' }

      it { is_expected.to eq('Some category') }
    end
  end

  describe '.question_for' do
    subject(:question_for) { described_class.question_for(facet) }

    context 'when the facet has a question in the facet settings file' do
      let(:facet) { 'animal_product_state' }

      it { is_expected.to eq('What state is the animal in?') }
    end

    context 'when the facet does not have a question in the facet settings file' do
      let(:facet) { 'herb_spice_state' }

      it { is_expected.to eq('Pick one of Herb / spice state') }
    end

    context 'when the facet does not have a question or display name in the facet settings file' do
      let(:facet) { 'some_category' }

      it { is_expected.to eq('Pick one of Some category') }
    end
  end

  describe '.boost_for' do
    subject(:boost_for) { described_class.boost_for(facet) }

    context 'when the facet is `entity`' do
      let(:facet) { 'entity' }

      it { is_expected.to eq(10) }
    end

    context 'when the facet is not `entity`' do
      let(:facet) { 'herb_spice_state' }

      it { is_expected.to eq(1) }
    end
  end

  describe '.empty' do
    subject(:empty) { described_class.empty }

    it { is_expected.to be_a(described_class) }
    it { expect(empty.classifications).to eq({}) }
  end
end
