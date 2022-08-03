require 'rails_helper'

RSpec.describe Search::ChapterIndex do
  subject(:index) { described_class.new('testnamespace') }

  let(:record) { create(:chapter) }

  it { is_expected.to have_attributes type: 'chapter' }
  it { is_expected.to have_attributes name: 'testnamespace-chapters' }
  it { is_expected.to have_attributes name_without_namespace: 'ChapterIndex' }
  it { is_expected.to have_attributes model_class: Chapter }
  it { is_expected.to have_attributes serializer: Search::ChapterSerializer }

  describe '#serialize_record' do
    subject { index.serialize_record record }

    it { is_expected.to include 'id' => record.goods_nomenclature_sid }
    it { is_expected.to include 'description' => record.description.presence }
  end
end
