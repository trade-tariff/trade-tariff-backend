class TaricImporter
  module Helpers
    module StringHelper
      extend ActiveSupport::Concern

      private

      def fast_classify(string)
        # We can do safe assumptions with the name of the class, using ActiveSupport
        # 'classify' method will be 5.47x slower
        string = if string =~ %r{(s)eries$} # singularize
                   string.sub(%r{(s)eries$}, '\\1eries')
                 else
                   string.sub(%r{s$}, '')
                 end
        string.gsub(%r{(^|_)(.)}) { $2.upcase } # camelize
      end
    end
  end
end
