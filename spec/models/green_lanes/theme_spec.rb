RSpec.describe GreenLanes::Theme do
  describe 'attributes' do
    it { is_expected.to respond_to :section }
    it { is_expected.to respond_to :subsection }
    it { is_expected.to respond_to :theme }
    it { is_expected.to respond_to :description }
    it { is_expected.to respond_to :category }
    it { is_expected.to respond_to :created_at }
    it { is_expected.to respond_to :updated_at }
  end

  describe 'validations' do
    subject(:errors) { instance.tap(&:valid?).errors }

    let(:instance) { described_class.new }

    it { is_expected.to include section: ['is not present'] }
    it { is_expected.to include subsection: ['is not present'] }
    it { is_expected.to include theme: ['is not present'] }
    it { is_expected.to include description: ['is not present'] }
    it { is_expected.to include category: ['is not present'] }

    context 'with blank theme' do
      let(:instance) { described_class.new theme: '' }

      it { is_expected.to include theme: ['is not present'] }
    end

    context 'with duplicate section and subsection' do
      let(:existing) { create :green_lanes_theme }

      let :instance do
        described_class.new section: existing.section,
                            subsection: existing.subsection
      end

      it { is_expected.to include %i[section subsection] => ['is already taken'] }
    end
  end

  describe 'date fields' do
    subject { create(:green_lanes_theme).reload }

    it { is_expected.to have_attributes created_at: be_within(1.minute).of(Time.zone.now) }
    it { is_expected.to have_attributes updated_at: be_within(1.minute).of(Time.zone.now) }
  end

  describe 'associations' do
    describe '#category_assessments' do
      subject { theme.reload.category_assessments }

      before { category_assessment }

      let(:theme) { create :green_lanes_theme }
      let(:category_assessment) { create :category_assessment, theme: }

      it { is_expected.to include category_assessment }

      context 'with for different theme' do
        subject { create(:green_lanes_theme).reload.category_assessments }

        it { is_expected.not_to include category_assessment }
      end
    end
  end

  describe '#to_s' do
    subject do
      described_class.create(section: 1,
                             subsection: 2,
                             category: 1,
                             theme: 'Short desc',
                             description: 'Long description').to_s
    end

    it { is_expected.to eq '1.2. Long description' }
  end

  describe '#code' do
    subject { create(:green_lanes_theme, section: 2, subsection: 3).code }

    it { is_expected.to eq '2.3' }
  end
end
