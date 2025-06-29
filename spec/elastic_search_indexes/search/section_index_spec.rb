RSpec.describe Search::SectionIndex do
  subject(:instance) { described_class.new 'testnamespace' }

  it { is_expected.to have_attributes type: 'section' }
  it { is_expected.to have_attributes name: 'testnamespace-sections-uk' }
  it { is_expected.to have_attributes name_without_namespace: 'SectionIndex' }
  it { is_expected.to have_attributes model_class: Section }
  it { is_expected.to have_attributes serializer: Search::SectionSerializer }

  describe '#serialize_record' do
    subject { instance.serialize_record record }

    let(:record) { create :section }

    it { is_expected.to include 'id' => record.id }
  end

  describe 'dataset_page' do
    subject { instance.dataset_page(page).map(&:position) }

    before { create_list :section, 5 }

    let(:page) { 1 }

    it { is_expected.to eql (1..5).to_a }

    context 'with higher page number' do
      let(:page) { 2 }

      it { is_expected.to be_empty }
    end
  end
end
