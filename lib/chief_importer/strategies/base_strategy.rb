require 'digest'
require 'ostruct'

class ChiefImporter
  module Formatters
    class ChiefCode
      def self.format(value)
        (value == 'null') ? nil : value.gsub(/\s+/, '')
      end
    end
    class ChiefDate
      def self.format(value)
        (value == 'null') ? nil : DateTime.strptime(value, '%d/%m/%Y:%H:%M:%S')
      end
    end
    class ChiefString
      def self.format(value)
        (value == 'null') ? nil : value
      end
    end
    class ChiefDecimal
      def self.format(value)
        (value == 'null') ? nil : value.to_f
      end
    end
    class ChiefBoolean
      def self.format(value)
        (value == 'N') ? false : true
      end
    end
  end

  module Strategies
    class BaseStrategy
      attr_accessor :operation, :identifier, :params,
                    :attributes, :origin

      def initialize(attributes = [])
        self.attributes = attributes
        self.operation = attributes[1]
      end

      def operation=(operation)
        @operation = case operation
                     when 'X' then :delete
                     when 'U' then :update
                     when 'I' then :insert
                     end
      end

      def map
        @_map ||= begin
                    attribute_map.inject({}) { |memo, key|
                      if key.last.is_a?(Array)
                        memo.merge!(Hash[key.first, formatter_for(key.last.last).format(attributes[key.last.first])])
                      elsif key.last.is_a?(Integer)
                        memo.merge!(Hash[key.first, attributes[key.last]])
                      end

                      memo
                    }.merge(origin: origin)
                  end
      end

      # TODO can these be delegated easily?
      def attribute_map; self.class.attribute_map; end
      def processor; self.class.processor; end

      def process!
        # execute either defined or default strategy process action
        if processor.has_key?(operation) && processor[operation].is_a?(Proc)
          instance_eval(&processor[operation])
        end

        self
      end

      def id(*keys)
        Digest::SHA1.hexdigest(keys.join(''))
      end

      def formatter_for(format)
        "ChiefImporter::Formatters::#{format.to_s.classify}".classify.constantize
      end


      ##########################################
      #  CHIEF CONSTANTS
      #########################################
      VALID_RESTRICTION_GROUP_CODES = %(DL PR DP DO HO)
      VALID_EXCISE_VAT_GROUP_CODES = %(EX VT)
      EXCLUDED_MEASURE_TYPES = %(DL:SPL DO:DTI PR:ICP PR:ECP PR:ETF PR:TFC
                              PR:PRW PR:DOH PR:IOD PR:KIM PR:EKM DL:OGL
                              PR:PRP PR:PRS PR:PRZ)

      ##########################################
      #  CHIEF RULES
      #########################################

      def prohibition_or_restriction?(group)
        VALID_RESTRICTION_GROUP_CODES.include?(group)
      end

      def vat_or_excise?(group)
        VALID_EXCISE_VAT_GROUP_CODES.include?(group)
      end

      # Should skip types already covered by TARIC
      def excluded_measure?(group, type)
        EXCLUDED_MEASURE_TYPES.include?("#{group}:#{type}")
      end

      # If code contains a letter, then it's UK Seasonal and should
      # be skipped
      def seasonal_measure?(code)
        code.match(/\D/)
      end

      # Used to support DSL declarations in strategies
      class << self
        attr_reader :attribute_map

        def map(attribute_map = {})
          @attribute_map = attribute_map
        end

        def processor
          @processor ||= {}
        end

        def process(operation, &block)
          @processor ||= {}
          @processor.deep_merge!(Hash[operation, block]) if block_given?
        end
      end
    end
  end
end
