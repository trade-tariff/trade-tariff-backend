RSpec.describe Sequel::Plugins::HasPaperTrail do
  let(:model_with_plugin) { create :section_note, content: 'first content' }

  describe 'version tracking' do
    it 'creates a version record on create' do
      expect {
        create :section_note, content: 'new content'
      }.to change(Version, :count).by(1)

      version = Version.last
      expect(version.event).to eq('create')
      expect(version.item_type).to eq('SectionNote')
    end

    it 'creates a version record on update' do
      model_with_plugin

      expect {
        model_with_plugin.update(content: 'updated content')
      }.to change(Version, :count).by(1)

      version = Version.last
      expect(version.event).to eq('update')
      expect(version.object['content']).to eq('updated content')
    end

    it 'creates a version record on destroy' do
      model_with_plugin

      expect {
        model_with_plugin.destroy
      }.to change(Version, :count).by(1)

      version = Version.last
      expect(version.event).to eq('destroy')
    end

    it 'stores a full snapshot of the object' do
      model_with_plugin.update(content: 'snapshot test')

      version = Version.last
      snapshot = version.object.to_hash
      expect(snapshot).to include('content' => 'snapshot test')
      expect(snapshot).to have_key('section_id')
    end
  end

  describe '#versions' do
    it 'returns versions for the record' do
      model_with_plugin.update(content: 'v2')
      model_with_plugin.update(content: 'v3')

      versions = model_with_plugin.versions.all
      expect(versions.size).to be >= 2
      expect(versions.map(&:item_type).uniq).to eq(%w[SectionNote])
    end
  end

  describe 'whodunnit tracking' do
    it 'stores whodunnit from TradeTariffRequest' do
      TradeTariffRequest.whodunnit = 'user-123'
      model_with_plugin.update(content: 'tracked change')
      TradeTariffRequest.whodunnit = nil

      version = Version.last
      expect(version.whodunnit).to eq('user-123')
    end

    it 'stores nil whodunnit when not set' do
      TradeTariffRequest.whodunnit = nil
      model_with_plugin.update(content: 'untracked change')

      version = Version.last
      expect(version.whodunnit).to be_nil
    end
  end

  describe '.without_paper_trail' do
    it 'suppresses version creation within the block' do
      model_with_plugin

      expect {
        SectionNote.without_paper_trail do
          model_with_plugin.update(content: 'silent change')
        end
      }.not_to change(Version, :count)
    end

    it 'restores version creation after the block' do
      model_with_plugin

      SectionNote.without_paper_trail do
        model_with_plugin.update(content: 'silent')
      end

      expect {
        model_with_plugin.update(content: 'loud change')
      }.to change(Version, :count).by(1)
    end

    it 'restores version creation even if the block raises' do
      model_with_plugin

      begin
        SectionNote.without_paper_trail do
          raise 'boom'
        end
      rescue RuntimeError
        nil
      end

      expect {
        model_with_plugin.update(content: 'after error')
      }.to change(Version, :count).by(1)
    end
  end
end
