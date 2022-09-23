require 'rails_helper'

RSpec.describe Cache::FootnoteIndex do
  subject(:instance) { described_class.new 'testnamespace' }

  it { is_expected.to have_attributes type: 'footnote' }
  it { is_expected.to have_attributes name: 'testnamespace-footnotes-uk-cache' }
  it { is_expected.to have_attributes name_without_namespace: 'FootnoteIndex' }
  it { is_expected.to have_attributes model_class: Footnote }
  it { is_expected.to have_attributes serializer: Cache::FootnoteSerializer }

  describe '#serialize_record' do
    subject { instance.serialize_record record }

    let(:record) { create :footnote }

    it { is_expected.to include footnote_id: record.footnote_id }
  end
end
