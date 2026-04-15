namespace :paper_trail do
  desc 'DANGER: Truncate versions and rebuild create snapshots from the current database state. Set CONFIRM=true.'
  task reset_initial_versions: :class_eager_load do
    unless ENV['CONFIRM'] == 'true'
      puts 'WARNING: This will truncate all versions and rebuild create snapshots from current records.'
      puts 'Set CONFIRM=true to proceed.'
      exit 1
    end

    puts 'Resetting PaperTrail versions...'
    PaperTrail::ResetInitialVersions.new.call
    puts 'Done.'
  end
end
