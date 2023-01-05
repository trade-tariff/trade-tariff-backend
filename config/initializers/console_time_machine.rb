module ConsoleTimeMachine
  def start(...)
    # rubocop:disable Rails/Output
    puts 'Setting TimeMachine to Today'
    # rubocop:enable Rails/Output

    TimeMachine.now { super }
  end
end

Rails::Console.prepend(ConsoleTimeMachine) if defined?(Rails::Console)
