namespace :self_texts do
  desc 'Generate self-texts for all chapters (background) or a single chapter (inline with CHAPTER=XX)'
  task generate: :environment do
    if ENV['CHAPTER']
      chapter = TimeMachine.now { Chapter.actual.by_code(ENV['CHAPTER']).take }
      raise "Chapter #{ENV['CHAPTER']} not found" unless chapter

      puts "Generating self-texts for chapter #{ENV['CHAPTER']}..."
      mechanical = GenerateSelfText::MechanicalBuilder.call(chapter)
      ai = GenerateSelfText::AiBuilder.call(chapter)
      puts "Mechanical: #{mechanical.inspect}"
      puts "AI: #{ai.inspect}"
    else
      puts 'Enqueuing self-text generation for all chapters...'
      GenerateSelfTextWorker.perform_async
      puts 'Done. Check Sidekiq for progress.'
    end
  end
end
