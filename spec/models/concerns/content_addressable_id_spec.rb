RSpec.describe ContentAddressableId do
  describe '#id' do
    subject { first.id }

    let :model do
      Class.new do
        include ContentAddressableId
        content_addressable_fields 'first_name', 'last_name'

        attr_accessor :first_name, :last_name, :age

        def initialize(attrs = {})
          attrs.each { |k, v| public_send "#{k}=", v }
        end
      end
    end

    let(:first) { model.new first_name: 'Joe', last_name: 'Bloggs', age: 20 }
    let(:matching) { model.new first_name: 'Joe', last_name: 'Bloggs', age: 30 }
    let(:different) { model.new first_name: 'Steve', last_name: 'Bloggs', age: 40 }

    it { is_expected.to eql matching.id }
    it { is_expected.not_to eql different.id }
  end
end
