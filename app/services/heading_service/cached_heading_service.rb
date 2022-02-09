module HeadingService
  class CachedHeadingService
    def initialize(heading)
      @heading = heading
    end

    def call
      Api::V2::Headings::HeadingPresenter.build(@heading)
    end
  end
end
