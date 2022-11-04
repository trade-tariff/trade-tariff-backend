RSpec.describe Api::Admin::ErrorSerializationService do
  describe '#call' do
    subject { described_class.new(instance).call }

    let(:instance) { News::Collection.new }

    context 'with errors' do
      before { instance.valid? }

      let :error_response do
        {
          errors: [
            {
              status: 422,
              title: 'is not present',
              detail: 'Name is not present',
              source: {
                pointer: '/data/attributes/name',
              },
            },
          ],
        }
      end

      it { is_expected.to eql error_response }
    end

    context 'with multiple errors' do
      before { instance.validate }

      let :error_response do
        {
          errors: [
            {
              status: 422,
              title: 'is not present',
              detail: 'Name is not present',
              source: {
                pointer: '/data/attributes/name',
              },
            },
            {
              status: 422,
              title: 'is not present',
              detail: 'Created at is not present',
              source: {
                pointer: '/data/attributes/created_at',
              },
            },
          ],
        }
      end

      it { is_expected.to eql error_response }
    end

    context 'with multiple errors per attribute' do
      before do
        instance.valid?
        instance.validate
      end

      let :error_response do
        {
          errors: [
            {
              status: 422,
              title: 'is not present',
              detail: 'Name is not present',
              source: {
                pointer: '/data/attributes/name',
              },
            },
            {
              status: 422,
              title: 'is not present',
              detail: 'Name is not present',
              source: {
                pointer: '/data/attributes/name',
              },
            },
          ],
        }
      end

      it { is_expected.to eql error_response }
    end

    context 'with conflict error' do
      before do
        News::Collection.create name: instance.name
        instance.valid?
      end

      let(:instance) { build :news_collection }

      let :error_response do
        {
          errors: [
            {
              status: 409,
              title: 'is already taken',
              detail: 'Name is already taken',
              source: {
                pointer: '/data/attributes/name',
              },
            },
          ],
        }
      end

      it { is_expected.to eql error_response }
    end

    context 'without errors' do
      it { is_expected.to eql(errors: []) }
    end
  end
end
