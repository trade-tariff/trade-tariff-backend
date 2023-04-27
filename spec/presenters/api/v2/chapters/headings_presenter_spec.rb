RSpec.describe Api::V2::Chapters::HeadingPresenter do
  let(:nongrouping) { build_list :heading, 3, :non_grouping }
  let(:grouping) { build :heading, :grouping }

  describe '.nest' do
    subject { described_class.nest headings }

    context 'with flat set of headings' do
      let(:headings) { nongrouping }

      it { is_expected.to eq(headings[0] => nil, headings[1] => nil, headings[2] => nil) }
    end

    context 'when all nested' do
      let(:headings) { [grouping] + nongrouping }

      it { is_expected.to eq(grouping => nongrouping) }
    end

    context 'when some are nested' do
      let(:headings) { [nongrouping1, grouping] + nongrouping }
      let(:nongrouping1) { build :heading, :non_grouping }

      it { is_expected.to eq(nongrouping1 => nil, grouping => nongrouping) }
    end

    context 'when pls decreases again' do
      let(:grouping2) { build :heading, :grouping }
      let(:grouping3) { build :heading, :grouping }
      let(:headings) { [grouping] + nongrouping + [grouping2, grouping3] }

      it { is_expected.to eq grouping => nongrouping, grouping2 => nil, grouping3 => nil }
    end

    context 'with multiple trees in set' do
      let(:grouping2) { build :heading, :grouping }
      let(:nongrouping2) { build_list :heading, 2, :non_grouping }
      let(:headings) { [grouping] + nongrouping + [grouping2] + nongrouping2 }

      it { is_expected.to eq grouping => nongrouping, grouping2 => nongrouping2 }
    end
  end

  describe '.wrap' do
    subject(:wrapped) { described_class.wrap headings }

    let(:headings) { [grouping] + nongrouping }

    it { expect(wrapped.map(&:pk)).to eq [grouping.pk] }
    it { expect(wrapped.first.children.map(&:pk)).to eq nongrouping.map(&:pk) }
    it { expect(wrapped.first.children).to all be_instance_of described_class }
  end
end
