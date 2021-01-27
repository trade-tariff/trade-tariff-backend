require 'rails_helper'

RSpec.describe Clearable do
  let(:mocked_model) do
    Struct.new('Commodity') do
      include Clearable

      def self.association_reflections
        @association_reflections ||=
          begin
            {
              foo: { cache: { rows: ['some stuff'] } },
              bar: { cache: {} },
              baz: { flibble: { some_option: true } },

            }
          end
      end
    end
  end

  it 'clears association reflection caches' do
    mocked_model.clear_association_cache

    expect(mocked_model.association_reflections).to eq(
      foo: { cache: {} },
      bar: { cache: {} },
      baz: { flibble: { some_option: true } },
    )
  end
end
