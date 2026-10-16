module ConsoleTimeMachine
  def start(...)
    $stdout.puts 'Setting TimeMachine to Today'

    TimeMachine.now { super }
  end
end

Rails::Console.prepend(ConsoleTimeMachine) if defined?(Rails::Console)
