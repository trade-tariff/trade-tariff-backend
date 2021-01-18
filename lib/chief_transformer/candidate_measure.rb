require 'chief_transformer/candidate_measure/collection'
require 'chief_transformer/candidate_measure/candidate_associations'

class ChiefTransformer
  class CandidateMeasure < Sequel::Model(:measures_oplog)
    set_primary_key :measure_sid

    plugin :national
    plugin :timestamps
    plugin :after_initialize

    DEFAULT_REGULATION_ROLE_TYPE_ID = 1
    DEFAULT_REGULATION_ID = 'IYY99990'.freeze
    DEFAULT_GEOGRAPHICAL_AREA_ID = '1011'.freeze #ERGA OMNES

    EXCISE_GROUP_CODES = %w[EX].freeze
    VAT_GROUP_CODES = %w[VT].freeze
    RESTRICTION_GROUP_CODES = %w[DL PR DP DO HO].freeze
    NATIONAL_MEASURE_TYPES = %w[AIL DPO EXA EXB EXC EXD EXF DAA DAB DAC DAE DAI
                                DBA DBB DBC DBE DBI DCA DCC DCE DCH DDJ DDA
                                DDB DDC DDD DDE DDF DDG DEA DFA DFB DFC DGC
                                DHA DHC DHE EAA EAE EBJ EBA EBB EBE EDJ EDA
                                EDB EDE EEA EEF EFJ EFA EGJ EGA EGB EHI EIJ
                                EIA EIB EIC EID EIE FAA FAE FAI FBC FBG LAA
                                LAE LBJ LBA LBB LBE LDA LEA LEF LFA LGJ COE
                                PRE AHC ATT CEX CHM COI CVD ECM EHC EQC EWP
                                HOP HSE IWP PHC PRT QRC SFS VTA VTE VTS VTZ].freeze

    attr_accessor :mfcm, :tame, :tamf, :candidate_associations, :initiator, :operation
    attr_reader :chief_geographical_area

    delegate :persist, :map, to: :candidate_associations, prefix: true
    delegate :fe_tsmp, to: :tame, prefix: true

    def after_initialize
      # set default variables
      set(measure_generating_regulation_id: DEFAULT_REGULATION_ID,
           measure_generating_regulation_role: DEFAULT_REGULATION_ROLE_TYPE_ID,
           stopped_flag: false,
           national: true)

      set(geographical_area_id: DEFAULT_GEOGRAPHICAL_AREA_ID) if geographical_area_id.blank?

      callbacks
    end

    def before_validation
      # set excluded_country geographical area_sid
      # must happen after validity dates are set, depends on start date
      self.additional_code_sid = AdditionalCode.where(additional_code_type_id: additional_code_type_id,
                                                      additional_code: additional_code_id)
                                               .where('validity_start_date <= ? AND (validity_end_date >= ? OR validity_end_date IS NULL)', validity_start_date, validity_end_date)
                                               .first
                                               .try(:additional_code_sid)
      # needs to throw errors about invalid geographical area
      self.geographical_area_sid = GeographicalArea.where(geographical_area_id: geographical_area_id)
                                                   .where('validity_start_date <= ? AND (validity_end_date >= ? OR validity_end_date IS NULL)', validity_start_date, validity_end_date)
                                                   .first
                                                   .try(:geographical_area_sid)
      if self.geographical_area_sid.blank?
        self[:geographical_area_id] = DEFAULT_GEOGRAPHICAL_AREA_ID

        self.geographical_area_sid = GeographicalArea.where(geographical_area_id: geographical_area_id)
                                                     .where('validity_start_date <= ? AND (validity_end_date >= ? OR validity_end_date IS NULL)', validity_start_date, validity_end_date)
                                                     .first
                                                     .try(:geographical_area_sid)
      end

      # needs to throw errors about invalid goods nomenclature item found
      # we should check previous months in case CHIEF changes come before TARIC
      gono_sid = nil
      [0, 1, 2, 3, 4].each do |num|
        gono_sid = GoodsNomenclature.where(goods_nomenclature_item_id: goods_nomenclature_item_id)
                                    .where('validity_start_date <= ? AND (validity_end_date >= ? OR validity_end_date IS NULL)',
                                           validity_start_date ? validity_start_date + num.month : validity_start_date,
                                           validity_end_date ? validity_end_date + num.month : validity_end_date)
                                    .declarable
                                    .order(Sequel.desc(:validity_start_date))
                                    .first
                                    .try(:goods_nomenclature_sid)
        break if gono_sid.present?
      end
      self.goods_nomenclature_sid = gono_sid

      # assign negative, National sid before saving record
      self.measure_sid = self.class.next_national_sid

      super
    end

    def after_save
      # traverse associations hash, create association records
      candidate_associations_persist

      super
    end

    def before_save
      exclusion_entry = Chief::CountryGroup.where(chief_country_grp: chief_geographical_area).first
      if exclusion_entry.present? && exclusion_entry.country_exclusions.present?
        exclusion_entry.country_exclusions.split(',').each do |excluded_chief_code|
          excluded_geographical_area = GeographicalArea.where(geographical_area_id: Chief::CountryCode.to_taric(excluded_chief_code))
                                                       .latest
                                                       .first

          if excluded_geographical_area.present?
            exclusion = MeasureExcludedGeographicalArea.new do |mega|
              mega.geographical_area_sid = excluded_geographical_area.geographical_area_sid
              mega.excluded_geographical_area = excluded_geographical_area.geographical_area_id
            end

            candidate_associations.push(:excluded_geographical_areas, exclusion)
          end
        end
      end

      super
    end

    def callbacks
      assign_dates if mfcm
      assign_mfcm_attributes if mfcm
      build_conditions if tamf
      build_components
      build_footnotes
    end

    def rebuild
      # clear pre-built
      @candidate_associations = CandidateAssociations.new(self)
      # re-run the drill
      callbacks
    end

    def self.validations
      []
    end

    def validate
      super

      errors.add(:mfcm, 'must be set') if mfcm.blank?
      errors.add(:tame_tamf, 'tame or tamf must be set') if tame.blank? && tamf.blank?
      errors.add(:goods_nomenclature_item_id, 'commodity code should have 10 symbol length') if goods_nomenclature_item_id.present? && goods_nomenclature_item_id.size != 10
      errors.add(:measure_type_id, 'measure_type must be present') if measure_type_id.blank?
      errors.add(:measure_type_id, 'must have national measure type') if measure_type_id.present? && !measure_type_id.in?(NATIONAL_MEASURE_TYPES)
      if goods_nomenclature_sid.blank?
        gonos = GoodsNomenclature.where(goods_nomenclature_item_id: goods_nomenclature_item_id).declarable.select_map(%i[goods_nomenclature_sid validity_start_date validity_end_date])
        errors.add(:goods_nomenclature_sid, "not found within validity dates, others found #{gonos.inspect} ")
      end
      errors.add(:geographical_area_sid, 'must be present') if geographical_area_sid.blank?
      errors.add(:validity_end_date, 'start date greater than end date') if validity_end_date.present? && validity_start_date >= validity_end_date
      errors.add(:measure_sid, 'measure must be unique') if Measure.where(measure_type_id: measure_type_id,
                                                                          geographical_area_id: geographical_area_id,
                                                                          validity_start_date: validity_start_date,
                                                                          validity_end_date: validity_end_date,
                                                                          goods_nomenclature_item_id: goods_nomenclature_item_id,
                                                                          additional_code_type_id: additional_code_type_id,
                                                                          additional_code_id: additional_code_id).national.any?
    end

    def assign_mfcm_attributes
      self.goods_nomenclature_item_id = mfcm.cmdty_code.size == 8 ? "#{mfcm.cmdty_code}00" : mfcm.cmdty_code
      self.measure_type_id = mfcm.measure_type_adco.measure_type_id.presence || mfcm.msr_type
      self.additional_code_id = mfcm.measure_type_adco.adtnl_cd
      self.additional_code_type_id = mfcm.measure_type_adco.adtnl_cd_type_id
      self.tariff_measure_number = mfcm.tar_msr_no
    end

    def assign_dates
      assign_validity_start_date
      assign_validity_end_date
    end

    def audit_tsmp
      tame.present? ? tame.audit_tsmp : mfcm.audit_tsmp
    end

    def assign_validity_start_date
      self.validity_start_date = [tame.try(:fe_tsmp), tamf.try(:fe_tsmp), mfcm.try(:fe_tsmp)].compact.max
    end

    def assign_validity_end_date
      self.validity_end_date = [tame.try(:le_tsmp), tamf.try(:le_tsmp), mfcm.try(:le_tsmp)].compact.min

      # We sometimes get rubbish data and the MFCM has a le_tsmp that is before the start date
      # Overwite the validity_end_date in this case
      if self.validity_start_date.present? && self.validity_end_date.present? && self.validity_end_date <= self.validity_start_date
        self.validity_end_date = nil
      end

      if self.validity_end_date.present?
        self.justification_regulation_role = DEFAULT_REGULATION_ROLE_TYPE_ID
        self.justification_regulation_id = DEFAULT_REGULATION_ID
      end
    end

    def chief_geographical_area=(chief_code)
      @chief_geographical_area = chief_code

      # chief country code converted to taric country code OR
      # chief country group code converted to taric country code OR
      # chief country code as is
      self[:geographical_area_id] = Chief::CountryCode.to_taric(chief_code) ||
        Chief::CountryGroup.to_taric(chief_code) ||
        chief_code
    end

    def candidate_associations
      @candidate_associations ||= CandidateAssociations.new(self)
    end

    def is_vat_or_excise?
      mfcm.present? && (mfcm.msrgp_code.in?(EXCISE_GROUP_CODES) || mfcm.msrgp_code.in?(VAT_GROUP_CODES))
    end

    def is_vat?
      mfcm.present? && mfcm.msrgp_code.in?(VAT_GROUP_CODES)
    end

    def is_prohibition_or_restriction?
      mfcm.present? && mfcm.msrgp_code.in?(RESTRICTION_GROUP_CODES)
    end

    def origin
      [mfcm.try(:origin), tame.try(:origin), tamf.try(:origin)].find(&:present?)
    end

  private

    def build_conditions
      tamf.measure_type_conds.each do |chief_measure_condition|
        taric_measure_condition = MeasureCondition.new do |mc|
          mc.action_code = chief_measure_condition.act_cd
          mc.certificate_code = chief_measure_condition.cert_ref_no
          mc.certificate_type_code = chief_measure_condition.cert_type_cd
          mc.condition_code = chief_measure_condition.cond_cd
          mc.component_sequence_number = chief_measure_condition.comp_seq_no
        end

        candidate_associations.push(:measure_conditions, taric_measure_condition)
      end

      self.chief_geographical_area = tamf.geographical_area.presence || DEFAULT_GEOGRAPHICAL_AREA_ID
    end

    def build_components
      if tamf.present?
        build_components_from_tamf if is_vat_or_excise?
      elsif tame.present?
        build_components_from_tame if is_vat_or_excise?
      end
    end

    def build_components_from_tame
      if mfcm.measure_type_adco.present?
        if tame.adval_rate.blank? || tame.adval_rate < 0
          tame.adval_rate = 0
        end

        measure_component = MeasureComponent.new do |mc|
          mc.duty_amount = tame.adval_rate
          if tame.duty_expression.present?
            mc.duty_expression_id = tame.duty_expression.duty_expression_id_adval1
          end
        end

        candidate_associations.push(:measure_components, measure_component)
      end
    end

    def build_components_from_tamf
      components = tamf.measure_components

      unless components.present?
        # if no components found - find components with present adval1_rate
        tamf.adval1_rate = 0.0
        components = tamf.measure_components
      end

      candidate_associations.push(:measure_components, components)
    end

    def build_footnotes
      footnote = Chief::MeasureTypeFootnote.where(measure_type_id: measure_type_id).first

      if footnote.present?
        fnasm = FootnoteAssociationMeasure.new do |fam|
          fam.footnote_type_id = footnote.footn_type_id
          fam.footnote_id = footnote.footn_id
          fam.national = true
        end

        candidate_associations.push(:footnote_association_measures, fnasm)
      end
    end
  end
end
