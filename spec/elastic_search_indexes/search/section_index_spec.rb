require 'rails_helper'

RSpec.describe Search::SectionIndex do
  subject(:index) { described_class.new('testnamespace') }

  let(:record) { create :section }

  it { is_expected.to have_attributes type: 'section' }
  it { is_expected.to have_attributes name: 'testnamespace-sections' }
  it { is_expected.to have_attributes name_without_namespace: 'SectionIndex' }
  it { is_expected.to have_attributes model_class: Section }
  it { is_expected.to have_attributes serializer: Search::SectionSerializer }

  describe '#serialize_record' do
    subject { index.serialize_record record }

    it { is_expected.to include('id' => record.id) }
  end

  describe '#skip?' do
    it { expect(index.skip?(record)).to be(false) }
  end
end
