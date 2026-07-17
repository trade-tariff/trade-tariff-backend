class SelfTextGenerationRunner
  class << self
    def call(chapter_code)
      chapter_code ? generate_chapter(chapter_code) : enqueue_generation
    end

  private

    def generate_chapter(chapter_code)
      chapter = TimeMachine.now { Chapter.actual.by_code(chapter_code).take }

      $stdout.puts "Generating self-texts for chapter #{chapter_code}..."
      ai = GenerateSelfText::OtherSelfTextBuilder.call(chapter)
      non_other_ai = GenerateSelfText::NonOtherSelfTextBuilder.call(chapter)
      $stdout.puts "Other AI: #{ai.inspect}"
      $stdout.puts "Non-Other AI: #{non_other_ai.inspect}"
    end

    def enqueue_generation
      $stdout.puts 'Enqueuing self-text generation for all chapters...'
      GenerateSelfTextWorker.perform_async
      $stdout.puts 'Done. Check Sidekiq for progress.'
    end
  end
end
