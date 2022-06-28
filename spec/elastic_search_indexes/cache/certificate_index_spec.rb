require 'rails_helper'

RSpec.describe Cache::CertificateIndex do
  subject(:instance) { described_class.new 'testnamespace' }

  it { is_expected.to have_attributes type: 'certificate' }
  it { is_expected.to have_attributes name: 'testnamespace-certificates-cache' }
  it { is_expected.to have_attributes model_class: Certificate }
  it { is_expected.to have_attributes serializer: Cache::CertificateSerializer }

  describe '#serialize_record' do
    subject { instance.serialize_record record }

    let(:record) { create :certificate, :with_description }

    it { is_expected.to include id: record.id }
  end
end
