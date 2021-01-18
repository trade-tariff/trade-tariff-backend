module Chief
  class Mfcm < Sequel::Model(Sequel::Model.db[:chief_mfcm].order(Sequel.asc(:audit_tsmp), Sequel.asc(:fe_tsmp)))
    EXCISE_GROUP_CODES = %w[EX]
    VAT_GROUP_CODES = %w[VT]

    set_primary_key [:msrgp_code,
                     :msr_type,
                     :tty_code,
                     :tar_msr_no,
                     :cmdty_code,
                     :fe_tsmp,
                     :le_tsmp,
                     :audit_tsmp,
                     :amend_indicator]

    one_to_one :tame, key: {}, primary_key: {}, dataset: -> {
      Chief::Tame.filter({:msrgp_code => msrgp_code})
                 .filter({:msr_type => msr_type})
                 .filter({:tty_code => tty_code})
                 .filter({:tar_msr_no => tar_msr_no})
                 .order(Sequel.desc(:audit_tsmp))
    }, class_name: 'Chief::Tame'

    one_to_many :tames, key: {}, primary_key: {}, dataset: -> {
      Chief::Tame.filter({:msrgp_code => msrgp_code})
                 .filter({:msr_type => msr_type})
                 .filter({:tty_code => tty_code})
                 .filter({:tar_msr_no => tar_msr_no})
                 .order(Sequel.asc(:audit_tsmp))
    }, class_name: 'Chief::Tame'

    one_to_one :measure_type, key: {}, primary_key: {},
      dataset: -> { Chief::MeasureTypeAdco.where(chief_measure_type_adco__measure_group_code: msrgp_code,
                                                 chief_measure_type_adco__measure_type: msr_type,
                                                 chief_measure_type_adco__tax_type_code: tty_code) },
                                                 class_name: 'Chief::MeasureTypeAdco'

    one_to_one :chief_update, key: :filename,
                              primary_key: :origin,
                              class_name: TariffSynchronizer::ChiefUpdate

    delegate :issue_date, to: :chief_update, allow_nil: true

    dataset_module do
      def unprocessed
        filter(processed: false)
      end

      def valid_to(timestamp)
        where('fe_tsmp < ?', timestamp)
      end

      def initial_load
        where(origin: nil)
      end
    end

    def validate
      super

      errors.add(:name, 'cannot be seasonal commodity code') if cmdty_code.match(/\D/)
      errors.add(:name, 'cannot be pseudo commodity code') if cmdty_code.first(2) == '99'
    end

    def mark_as_processed!
      self.this.unlimited.update(processed: true)
    end

    def measure_type_adco
      Chief::MeasureTypeAdco.where(chief_measure_type_adco__measure_group_code: msrgp_code,
                                   chief_measure_type_adco__measure_type: msr_type,
                                   chief_measure_type_adco__tax_type_code: tty_code)
                            .first.presence || ::NullObject.new
    end

    def audit_tsmp
      self[:audit_tsmp].presence || Time.now
    end

    def operation_date
      issue_date
    end
  end
end
