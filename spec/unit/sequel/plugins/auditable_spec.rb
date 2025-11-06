RSpec.describe Sequel::Plugins::Auditable do
  let(:model_with_plugin) { create :section_note, content: 'first content' }

  context 'with Model hooks' do
    it 'creates an audit record when updated' do
      expect {
        model_with_plugin.update(content: 'test')
      }.to change(Audit, :count).by(1)
    end

    it 'the new audit record created keeps the record of the changes', :aggregate_failures do
      model_with_plugin.update(content: 'second content')
      result = model_with_plugin.audits.last.changes

      expect(result['content'][0]).to eq('first content')
      expect(result['content'][1]).to eq('second content')
    end
  end
end
