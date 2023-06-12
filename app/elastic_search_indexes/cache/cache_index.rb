module Cache
  class CacheIndex < ::SearchIndex
    def name
      "#{super}-cache"
    end

    def dataset
      TimeMachine.now { super.actual }
    end

    def dataset_page(...)
      TimeMachine.now { super }
    end

    def page_size
      5
    end
  end
end
