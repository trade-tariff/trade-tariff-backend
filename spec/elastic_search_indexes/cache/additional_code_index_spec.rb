require 'rails_helper'

RSpec.describe Cache::AdditionalCodeIndex do
  subject(:instance) { described_class.new 'testnamespace' }

  it { is_expected.to have_attributes type: 'additional_code' }
  it { is_expected.to have_attributes name: 'testnamespace-additional_codes-uk-cache' }
  it { is_expected.to have_attributes name_without_namespace: 'AdditionalCodeIndex' }
  it { is_expected.to have_attributes model_class: AdditionalCode }
  it { is_expected.to have_attributes serializer: Cache::AdditionalCodeSerializer }

  describe '#serialize_record' do
    subject { instance.serialize_record record }

    let(:record) { create :additional_code, :with_description }

    it { is_expected.to include additional_code_sid: record.additional_code_sid }
  end
end
