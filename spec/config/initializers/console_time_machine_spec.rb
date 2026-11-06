# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ConsoleTimeMachine do
  describe '#start' do
    let(:point_in_time_during_super) { [] }
    let(:console) { console_class.new }
    let(:console_class) do
      observed_point_in_time = point_in_time_during_super

      Class.new do
        prepend ConsoleTimeMachine

        define_method(:start) do
          observed_point_in_time << TimeMachine.point_in_time
          :started
        end
      end
    end

    # Examples already run inside TimeMachine.now. Clear that setting so this
    # example can see that #start sets the point in time only around super.
    it 'writes the banner and sets TimeMachine', :aggregate_failures do
      TimeMachine.no_time_machine do
        result = nil
        before_start = Time.current

        expect { result = console.start }.to output("Setting TimeMachine to Today\n").to_stdout
        after_start = Time.current

        expect(result).to eq(:started)
        # TimeMachine.now drops the fraction of a second, so the observed time
        # can be up to a second earlier than the moment #start ran. A fixed
        # tolerance around the current time fails when a second ticks over.
        expect(point_in_time_during_super).to contain_exactly(be_between(before_start.change(usec: 0), after_start))
        expect(TimeMachine.point_in_time).to be_nil
      end
    end
  end
end
