namespace :search_references do
  desc 'Remove Search references whose headings are inaccessible'

  task clean: :environment do
    SearchReference.where(referenced_class:'Heading').each do |ref|
      unless ref.heading.current?
        puts "Removing Search reference: id:#{ref.id}, title:#{ref.title}"
        ref.delete if ENV['CONFIRM_DELETION'] = 'true'
      end
    end
  end
end
