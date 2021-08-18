FactoryBot.factories.map(&:name).each do |factory_name|
  describe "#{factory_name} factory" do
    it 'is valid' do
      factory = build factory_name
      expect(factory).to be_valid if factory.respond_to?(:valid)
    end
  end
end
