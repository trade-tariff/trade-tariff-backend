RSpec.describe NullObject do
  subject(:null_object) { described_class.new }

  it 'is empty and blank', :aggregate_failures do
    expect(null_object).to be_empty
    expect(null_object).to be_blank
  end

  it 'does not silently accept unknown messages' do
    expect { null_object.unknown_method }.to raise_error(NoMethodError)
  end
end
