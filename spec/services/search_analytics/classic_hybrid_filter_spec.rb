RSpec.describe SearchAnalytics::ClassicHybridFilter do
  let(:db) { Sequel::Model.db }
  let(:columns) { { request_id: 'text', service: 'text', event: 'text', skip_question: 'boolean', request_source: 'text', '@logStream': 'text' } }

  def event(**attributes)
    { request_id: 'guided', service: 'search', event: 'search_started', skip_question: nil, request_source: 'frontend', '@logStream': 'ecs/backend-uk/test' }.merge(attributes)
  end

  it 'excludes only frontend skipped requests' do
    events = [event,
              event(event: 'interactive_configuration_used', skip_question: false),
              event(request_id: 'classic-hybrid'),
              event(request_id: 'classic-hybrid', event: 'interactive_configuration_used', skip_question: true, '@logStream': 'ecs/worker-uk/test'),
              event(request_id: 'legacy'),
              event(request_id: 'admin'),
              event(request_id: 'admin', event: 'interactive_configuration_used', skip_question: true, request_source: 'admin'),
              event(request_id: 'other-service'),
              event(request_id: 'other-service', event: 'interactive_configuration_used', skip_question: true, '@logStream': 'ecs/backend-xi/test'),
              event(request_id: nil),
              event(request_id: '')]
    values = events.map { |row| "(#{columns.map { |name, type| "#{db.literal(row.fetch(name))}::#{type}" }.join(', ')})" }
    names = columns.keys.map { |name| db.literal(Sequel.identifier(name)) }.join(', ')
    filter = described_class.call(source: 'events', log_stream_filter: "(`@logStream` LIKE '%ecs/backend-uk/%' OR `@logStream` LIKE '%ecs/worker-uk/%')").tr('`', '"')
    rows = db.fetch("WITH events(#{names}) AS (VALUES #{values.join(', ')}) SELECT request_id FROM events WHERE event = 'search_started' AND #{filter}").all

    expect(rows.map { |row| row[:request_id] }).to contain_exactly('guided', 'legacy', 'admin', 'other-service', nil, '')
  end
end
