report zatc_cloud_rdnss_2_cln_core.

parameters: summary radiobutton group mode default 'X',
            migrate radiobutton group mode.
selection-screen begin of block mapping_option with frame title text-rst.
  parameters: inclsucc radiobutton group opts default 'X' ##NEEDED,
              exclsucc radiobutton group opts.
selection-screen end of block mapping_option.
parameters: undo radiobutton group mode.


class cx_migration_error definition final inheriting from cx_static_check.

  public section.
    methods:
      constructor
        importing
          i_error_message type string,
      get_text redefinition.

  private section.
    data:
      error_message type string.

endclass.

class cx_migration_error implementation.

  method constructor.

    super->constructor( ).
    error_message = i_error_message.

  endmethod.


  method get_text.
    result = error_message.
  endmethod.

endclass.


class migration_handler definition final.

  public section.
    types:
      ty_exemption  type satc_ci_exempt,
      ty_exemptions type standard table of ty_exemption with default key,
      begin of ty_check_code,
        check_code type ty_exemption-chkcode,
      end of ty_check_code,
      ty_check_codes type sorted table of ty_check_code with unique key check_code,
      begin of ty_mapping_rule_check_codes,
        source_check_codes type ty_check_codes,
        object_type_range  type range of ty_exemption-objtype,
        target_check_codes type ty_check_codes,
      end of ty_mapping_rule_check_codes,
      begin of ty_mapping_rule_4_check_codes,
        index                    type sy-index, "Needed as unique key for definition of sorted table
        mapping_rule_check_codes type ty_mapping_rule_check_codes,
      end of ty_mapping_rule_4_check_codes,
      begin of ty_mapping_rules,
        mapping_rules_4_check_codes type sorted table of ty_mapping_rule_4_check_codes with unique key index,
      end of ty_mapping_rules,
      ty_migration_action type c length 1,
      begin of ty_migration_log,
        migration_id            type ty_exemption-exemption_id,
        started_at              type timestamp,
        omit_successor_codes    type abap_bool,
        last_step_completed_at  type timestamp,
        run_by                  type sy-uname,
        total_source_exemptions type i,
        total_target_exemptions type i,
        undone_by               type sy-uname,
        undone_at               type timestamp,
        finished                type abap_bool,
      end of ty_migration_log,
      ty_textpool type sorted table of textpool with unique key id key.

    constants:
      c_target_check_class      type ty_exemption-chkclass value 'CL_YCM_CC_CHECK_API_USAGE',
      c_target_checksum_version type ty_exemption-checksum_version value 1,
      c_migration_hint          type ty_exemption-xx_hint value 'CC',
      begin of c_migration_action,
        log_migration_step type ty_migration_action value 'S',
        finish_migration   type ty_migration_action value 'F',
        undo_migration     type ty_migration_action value 'U',
      end of c_migration_action,
      c_memory_id_for_initialization type c length 3 value 'IAC'.

    class-data:
      today                type sy-datum read-only,
      source_check_classes type range of ty_exemption-chkclass read-only.

    class-methods:
      class_constructor,
      get_mapping_rules
        importing
          i_omit_successor_codes type abap_bool
        returning
          value(result)          type ty_mapping_rules,
      derive_clean_core_xmpts
        importing
          i_source_exemptions    type ty_exemptions
          i_omit_successor_codes type abap_bool
        returning
          value(result)          type ty_exemptions,
      derive_date_and_time
        importing
          i_timestamp type timestamp
        exporting
          e_date      type string
          e_time      type string,
      read_migration_log
        returning
          value(result) type ty_migration_log,
      get_migratable_exemption_count
        returning
          value(result) type i,
      get_migrated_exemption_count
        returning
          value(result) type i,
      log_migration_action
        importing
          i_action                 type ty_migration_action default c_migration_action-log_migration_step
          i_omit_successor_codes   type abap_bool optional
          i_source_exemption_count type i optional
          i_target_exemption_count type i optional
        raising
          cx_migration_error,
      do_migration
        importing
          i_omit_successor_codes type abap_bool
        raising
          cx_migration_error,
      get_migration_comment
        returning
          value(result) type string,
      derive_migrated_assessment
        importing
          i_assessment  type ty_exemption-appr_comment
        returning
          value(result) type ty_exemption-appr_comment,
      undo_migration
        raising
          cx_migration_error,
      migration_is_locked
        exporting
          e_lock_owner  type sy-uname
        returning
          value(result) type abap_bool
        raising
          cx_migration_error,
      unlock_migration,
      do_initialization,
      is_authorized
        importing
          i_for_run_or_undo_migrations type abap_bool
        exporting
          e_error_message              type string
        returning
          value(result)                type abap_bool.

  private section.
    constants:
      c_migration_key type satc_ac_state-item_key value 'MIGRATION.CLD_RDNS_2_CLN_CORE',
      begin of c_locking_parameters,
        id    type ty_exemption-exemption_id value c_migration_hint, "Use any value that never can be confused with the ID of any created exemption
        mode  type enqmode value 'X',
        scope type c value '1',
      end of c_locking_parameters.

    class-data:
      may_run_or_undo_migrations     type abap_bool,
      may_read_migration_information type abap_bool.

    class-methods:
      lock_migration
        exporting
          e_was_already_locked type abap_bool
          e_lock_owner         type sy-uname
        raising
          cx_migration_error,

      migratable_exemption_may_exist
        returning
          value(result) type abap_bool,

      get_migratable_exemptions
        importing
          i_source_check_code           type migration_handler=>ty_check_code
          i_mapping_rules_4_check_codes type migration_handler=>ty_mapping_rule_4_check_codes
        exporting
          e_migratable_exemptions       type migration_handler=>ty_exemptions
          e_total_migratable_exemptions type i,

      adjust_texts_if_required
        importing
          i_required_text           type textpool
        changing
          c_original_texts          type ty_textpool
          c_insert_changed_textpool type abap_bool.

endclass.

class migration_handler implementation.

  method class_constructor.

    today = sy-datum.

    source_check_classes = value #( ( sign = 'I' option = 'EQ' low = 'CL_CLS_CI_CHECK_ENVIRONMENT' )
                                    ( sign = 'I' option = 'EQ' low = 'CL_CLS_CI_CHECK_E_ONPR_CLOUDIF' ) ).

    do 2 times.

      try.

          case sy-index.

            when 1.
              cl_satc_access_control_factory=>get_xmpt_access_control( )->confirm_exemption( ).
              may_read_migration_information = abap_true.
              may_run_or_undo_migrations     = abap_true.
              return.

            when 2.
              cl_satc_access_control_factory=>get_xmpt_access_control( )->display_exemption( ).
              may_read_migration_information = abap_true.

          endcase.

        catch cx_satc_no_authority into data(no_authorization).
          data(error_message) = no_authorization->get_text( ) ##NEEDED. "Could facilitate potential error analysis
      endtry.

    enddo.

  endmethod.


  method derive_clean_core_xmpts.

    if i_source_exemptions is initial.
      return.
    endif.

    loop at i_source_exemptions transporting no fields
      where    chkclass in source_check_classes
           and deleted  = abap_false
           and state    = if_satc_ci_exemption_root=>co_exemption_state-approved
           and (   valid_until is initial
                or valid_until >= today ).
      exit.

    endloop.

    if sy-subrc <> 0.
      return.
    endif.

    data(mapping_rules) = get_mapping_rules( i_omit_successor_codes = i_omit_successor_codes ).

    loop at mapping_rules-mapping_rules_4_check_codes assigning field-symbol(<mapping_rule_4_check_codes>).

      loop at i_source_exemptions into data(target_exemption)
        where    chkclass in source_check_classes
             and objtype  in <mapping_rule_4_check_codes>-mapping_rule_check_codes-object_type_range.

        read table <mapping_rule_4_check_codes>-mapping_rule_check_codes-source_check_codes
          with key check_code = target_exemption-chkcode
            transporting no fields.

        if sy-subrc <> 0.
          continue.
        endif.

        target_exemption-chkclass         = c_target_check_class.
        target_exemption-checksum_version = c_target_checksum_version.
        target_exemption-appr_comment     = derive_migrated_assessment( i_assessment = target_exemption-appr_comment ).

        loop at <mapping_rule_4_check_codes>-mapping_rule_check_codes-target_check_codes into target_exemption-chkcode.
          insert target_exemption into table result.
        endloop.

      endloop.

    endloop.

  endmethod.


  method derive_date_and_time.

    convert time stamp i_timestamp
            time zone sy-zonlo
            into date data(date)
                 time data(time).
    data: auxiliary_character_field type c length 20.

    write date to auxiliary_character_field.
    e_date = auxiliary_character_field.
    write time to auxiliary_character_field.
    e_time = auxiliary_character_field.


  endmethod.


  method read_migration_log.

    cl_satc_ac_state_access=>load_value(
      exporting
        i_key   = c_migration_key
      importing
        e_value = result ).

  endmethod.


  method get_mapping_rules.

    result-mapping_rules_4_check_codes = value #( ( index = 1
                                                    mapping_rule_check_codes = value #( source_check_codes = value #( ( check_code = '1' )
                                                                                                                      ( check_code = '5' )
                                                                                                                      ( check_code = '6' )
                                                                                                                      ( check_code = '7' ) )
                                                                                        object_type_range  = value #( sign = 'I' option = 'EQ' ( low = 'CLAS' )
                                                                                                                                               ( low = 'PROG' )
                                                                                                                                               ( low = 'FUGR' )
                                                                                                                                               ( low = 'FUGS' ) )
                                                                                        target_check_codes = cond ty_check_codes( when i_omit_successor_codes = abap_true
                                                                                                                                  then value #( ( check_code = 'SELECT'     )
                                                                                                                                                ( check_code = 'UPDATE'     )
                                                                                                                                                ( check_code = 'INTRNL'     )
                                                                                                                                                ( check_code = 'NOAPI'      )
                                                                                                                                                ( check_code = 'SBMT_PROG'  )
                                                                                                                                                ( check_code = 'PRFRM_PROG' ) )
                                                                                                                                  else value #( ( check_code = 'SELECT'     )
                                                                                                                                                ( check_code = 'UPDATE'     )
                                                                                                                                                ( check_code = 'INTRNL'     )
                                                                                                                                                ( check_code = 'NOAPI'      )
                                                                                                                                                ( check_code = 'NOAPI_SUC'  )
                                                                                                                                                ( check_code = 'SBMT_PROG'  )
                                                                                                                                                ( check_code = 'PRFRM_PROG' )
                                                                                                                                                ( check_code = 'SELECT_SUC' )
                                                                                                                                                ( check_code = 'UPDATE_SUC' )
                                                                                                                                                ( check_code = 'INTRNL_SUC' ) ) ) ) )
                                                  ( index = 2
                                                    mapping_rule_check_codes = value #( source_check_codes = value #( ( check_code = '1' )
                                                                                                                      ( check_code = '5' )
                                                                                                                      ( check_code = '6' )
                                                                                                                      ( check_code = '7' ) )
                                                                                        object_type_range  = value #( sign = 'I' option = 'EQ' ( low = 'DDLS' ) )
                                                                                        target_check_codes = cond ty_check_codes( when i_omit_successor_codes = abap_true
                                                                                                                                  then value #( ( check_code = 'DB_TAB_CDS' )
                                                                                                                                                ( check_code = 'NOAPI'      )
                                                                                                                                                ( check_code = 'INTRNL'     ) )
                                                                                                                                  else value #( ( check_code = 'DB_TAB_CDS' )
                                                                                                                                                ( check_code = 'INTRNL'     )
                                                                                                                                                ( check_code = 'NOAPI'      )
                                                                                                                                                ( check_code = 'NOAPI_SUC'  )
                                                                                                                                                ( check_code = 'DB_TAB_SUC' )
                                                                                                                                                ( check_code = 'INTRNL_SUC' ) ) ) ) )
                                                  ( index = 3
                                                    mapping_rule_check_codes = value #( source_check_codes = value #( ( check_code = '1' )
                                                                                                                      ( check_code = '5' )
                                                                                                                      ( check_code = '6' )
                                                                                                                      ( check_code = '7' ) )
                                                                                        object_type_range  = value #( sign = 'I' option = 'EQ' ( low = 'DEVC' ) )
                                                                                        " For packages map to the union of all the above target check codes
                                                                                        target_check_codes = cond ty_check_codes( when i_omit_successor_codes = abap_true
                                                                                                                                  then value #( ( check_code = 'SELECT'     )
                                                                                                                                                ( check_code = 'UPDATE'     )
                                                                                                                                                ( check_code = 'INTRNL'     )
                                                                                                                                                ( check_code = 'NOAPI'      )
                                                                                                                                                ( check_code = 'SBMT_PROG'  )
                                                                                                                                                ( check_code = 'PRFRM_PROG' )
                                                                                                                                                ( check_code = 'DB_TAB_CDS' ) )
                                                                                                                                  else value #( ( check_code = 'SELECT'     )
                                                                                                                                                ( check_code = 'UPDATE'     )
                                                                                                                                                ( check_code = 'INTRNL'     )
                                                                                                                                                ( check_code = 'NOAPI'      )
                                                                                                                                                ( check_code = 'NOAPI_SUC'  )
                                                                                                                                                ( check_code = 'SBMT_PROG'  )
                                                                                                                                                ( check_code = 'PRFRM_PROG' )
                                                                                                                                                ( check_code = 'DB_TAB_CDS' )
                                                                                                                                                ( check_code = 'SELECT_SUC' )
                                                                                                                                                ( check_code = 'UPDATE_SUC' )
                                                                                                                                                ( check_code = 'INTRNL_SUC' )
                                                                                                                                                ( check_code = 'DB_TAB_SUC' ) ) ) ) )
                                                  ( index = 4
                                                    mapping_rule_check_codes = value #( source_check_codes = value #( ( check_code = '1' )
                                                                                                                      ( check_code = '5' )
                                                                                                                      ( check_code = '6' )
                                                                                                                      ( check_code = '7' ) )
                                                                                        "All other object types
                                                                                        object_type_range  = value #( sign = 'E' option = 'EQ' ( low = 'CLAS' )
                                                                                                                                               ( low = 'PROG' )
                                                                                                                                               ( low = 'FUGR' )
                                                                                                                                               ( low = 'FUGS' )
                                                                                                                                               ( low = 'DDLS' )
                                                                                                                                               ( low = 'DEVC' ) )
                                                                                        target_check_codes = cond ty_check_codes( when i_omit_successor_codes = abap_true
                                                                                                                                  then value #( ( check_code = 'INTRNL'     )
                                                                                                                                                ( check_code = 'NOAPI'      ) )
                                                                                                                                  else value #( ( check_code = 'INTRNL'     )
                                                                                                                                                ( check_code = 'NOAPI'      )
                                                                                                                                                ( check_code = 'NOAPI_SUC'  )
                                                                                                                                                ( check_code = 'INTRNL_SUC' ) ) ) ) )
                                                  ( index = 5
                                                    mapping_rule_check_codes = value #( source_check_codes = value #( ( check_code = 'NOT_TO_REL' ) )
                                                                                        object_type_range  = value #( )
                                                                                        target_check_codes = cond ty_check_codes( when i_omit_successor_codes = abap_true
                                                                                                                                  then value #( ( check_code = 'INTRNL'     )
                                                                                                                                                ( check_code = 'NOAPI'      )
                                                                                                                                                ( check_code = 'CLSSIC'     )
                                                                                                                                                ( check_code = 'TC_CLA'     ) )
                                                                                                                                  else value #( ( check_code = 'INTRNL'     )
                                                                                                                                                ( check_code = 'NOAPI'      )
                                                                                                                                                ( check_code = 'NOAPI_SUC'  )
                                                                                                                                                ( check_code = 'CLSSIC'     )
                                                                                                                                                ( check_code = 'TC_CLA'     )
                                                                                                                                                ( check_code = 'INTRNL_SUC' )
                                                                                                                                                ( check_code = 'CLSSIC_SUC' )
                                                                                                                                                ( check_code = 'TC_CLA_SUC' ) ) ) ) )
                                                  ( index = 6
                                                    mapping_rule_check_codes = value #( source_check_codes = value #( ( check_code = '4' ) )
                                                                                        object_type_range  = value #( )
                                                                                        target_check_codes = cond ty_check_codes( when i_omit_successor_codes = abap_true
                                                                                                                                  then value #( ( check_code = 'DPRCTD'     ) )
                                                                                                                                  else value #( ( check_code = 'DPRCTD'     )
                                                                                                                                                ( check_code = 'DPRCTD_SUC' ) ) ) ) )
                                                  ( index = 7
                                                    mapping_rule_check_codes = value #( source_check_codes = value #( ( check_code = 'CLASSICAPI' ) )
                                                                                        object_type_range  = value #( )
                                                                                        target_check_codes = cond ty_check_codes( when i_omit_successor_codes = abap_true
                                                                                                                                  then value #( ( check_code = 'CLSSIC'     )
                                                                                                                                                ( check_code = 'TC_CLA'     ) )
                                                                                                                                  else value #( ( check_code = 'CLSSIC'     )
                                                                                                                                                ( check_code = 'TC_CLA'     )
                                                                                                                                                ( check_code = 'CLSSIC_SUC' )
                                                                                                                                                ( check_code = 'TC_CLA_SUC' ) ) ) ) )
                                                  ( index = 8
                                                    mapping_rule_check_codes = value #( source_check_codes = value #( ( check_code = 'NO_CLASSIC' ) )
                                                                                        object_type_range  = value #( )
                                                                                        target_check_codes = cond ty_check_codes( when i_omit_successor_codes = abap_true
                                                                                                                                  then value #( ( check_code = 'NOAPI'      ) )
                                                                                                                                  else value #( ( check_code = 'NOAPI'      )
                                                                                                                                                ( check_code = 'NOAPI_SUC'  ) ) ) ) ) ).
  endmethod.


  method lock_migration.

    clear e_lock_owner.
    clear e_was_already_locked.

    call function 'ENQUEUE_ESATC_CI_EXEMPT'
      exporting
        mode_satc_ci_exempt = c_locking_parameters-mode
        exemption_id        = c_locking_parameters-id
        _scope              = c_locking_parameters-scope
      exceptions
        foreign_lock        = 1
        system_failure      = 2.

    if sy-subrc = 0.
      return.
    endif.

    case sy-subrc.

      when 1.
        e_lock_owner = sy-msgv1.
        e_was_already_locked = abap_true.

      when 2.
        raise exception new cx_migration_error( i_error_message = conv #( 'System failure occurred, when trying to lock migration'(018) ) ).

    endcase.

  endmethod.


  method unlock_migration.

    call function 'DEQUEUE_ESATC_CI_EXEMPT'
      exporting
        mode_satc_ci_exempt = c_locking_parameters-mode
        exemption_id        = c_locking_parameters-id
        _scope              = c_locking_parameters-scope.

  endmethod.


  method log_migration_action.

    data(migration_log) = read_migration_log( ).

    case i_action.

      when c_migration_action-finish_migration.
        assert migration_log is not initial.
        migration_log-finished = abap_true.
        get time stamp field migration_log-last_step_completed_at.

      when c_migration_action-log_migration_step.

        if   migration_log is initial
          or (    migration_log-finished = abap_true
              and migration_log-undone_at > migration_log-last_step_completed_at ). "It must be possible to run an undone migration again

          migration_handler=>lock_migration(
            importing
              e_was_already_locked = data(was_already_locked)
              e_lock_owner         = data(lock_owner) ).

          if was_already_locked = abap_true.

            data: error_message    type string,
                  auxiliary_string type string.

            error_message = 'Migration already locked by user &'(023).
            auxiliary_string = lock_owner.
            replace '&' with auxiliary_string into error_message.
            raise exception new cx_migration_error( i_error_message = error_message ).

          endif.

          migration_log-migration_id = cl_satc_uuid_svc=>create_id( ).
          migration_log-omit_successor_codes = i_omit_successor_codes.
          clear migration_log-total_source_exemptions.
          clear migration_log-total_target_exemptions.
          migration_log-finished = abap_false.

          get time stamp field migration_log-started_at.
          migration_log-last_step_completed_at = migration_log-started_at.

        elseif migration_log-finished = abap_true.
          raise exception new cx_migration_error( i_error_message = conv #( 'Migration has already been run. Undo it first, if you want to run it again'(017) ) ).
        else.
          get time stamp field migration_log-last_step_completed_at.
        endif.

      when c_migration_action-undo_migration.

        "Make sure that the time stamp for a migration always is older than a subsequent undo time stamp.
        get time stamp field migration_log-undone_at.

        if migration_log-undone_at = migration_log-last_step_completed_at.

          wait up to 1 seconds.
          get time stamp field migration_log-undone_at.

        endif.

        migration_log-undone_by = sy-uname.

    endcase.

    if i_action <> c_migration_action-undo_migration.

      migration_log-run_by = sy-uname.
      migration_log-total_source_exemptions += i_source_exemption_count.
      migration_log-total_target_exemptions += i_target_exemption_count.

      if i_action = c_migration_action-finish_migration.
        migration_handler=>unlock_migration( ).
      endif.

    endif.

    cl_satc_ac_state_access=>save_value( i_key   = c_migration_key
                                         i_value = migration_log ).
  endmethod.


  method migration_is_locked.

    migration_handler=>lock_migration(
      importing
        e_was_already_locked = result
        e_lock_owner         = e_lock_owner ).

    if result = abap_false.
      migration_handler=>unlock_migration( ).
    endif.

  endmethod.


  method do_migration.

    migration_handler=>log_migration_action( i_omit_successor_codes = i_omit_successor_codes ).

    if migratable_exemption_may_exist( ).

      data(migration_log) = read_migration_log( ).

      data(mapping_rules) = get_mapping_rules( i_omit_successor_codes = abap_true ). "Successor codes not relevant for selecting the migratable exemptions

      loop at mapping_rules-mapping_rules_4_check_codes assigning field-symbol(<mapping_rules_4_check_codes>).

        loop at <mapping_rules_4_check_codes>-mapping_rule_check_codes-source_check_codes assigning field-symbol(<source_check_code>).

          get_migratable_exemptions(
          exporting
            i_source_check_code           = <source_check_code>
            i_mapping_rules_4_check_codes = <mapping_rules_4_check_codes>
          importing
            e_migratable_exemptions       = data(source_exemptions) ).

          if source_exemptions is initial.
            continue.
          endif.

          data(target_exemptions) = migration_handler=>derive_clean_core_xmpts(
            exporting
              i_source_exemptions    = source_exemptions
              i_omit_successor_codes = i_omit_successor_codes ).

          loop at target_exemptions assigning field-symbol(<target_exemption>).

            <target_exemption>-exemption_id = cl_satc_uuid_svc=>create_id( ).
            <target_exemption>-back_pack    = migration_log-migration_id.
            <target_exemption>-xx_hint      = migration_handler=>c_migration_hint.
            clear <target_exemption>-prev_state.

          endloop.

          insert satc_ci_exempt from table target_exemptions.

          log_migration_action( i_source_exemption_count = lines( source_exemptions )
                                i_target_exemption_count = lines( target_exemptions ) ).
        endloop.

      endloop.

    endif.

    log_migration_action( i_action = c_migration_action-finish_migration ).

  endmethod.


  method undo_migration.

    data(migration_log) = read_migration_log( ).

    if migration_log is initial.
      raise exception new cx_migration_error( i_error_message = conv #( 'Migration has not yet been run, hence cannot be undone'(022) ) ).
    endif.

    if migration_log-undone_at > migration_log-last_step_completed_at.
      raise exception new cx_migration_error( i_error_message = conv #( 'Migration has already been undone before'(019) ) ).
    endif.

    migration_handler=>lock_migration(
      importing
        e_was_already_locked = data(was_already_locked)
        e_lock_owner        = data(lock_owner) ).

    if was_already_locked = abap_true.

      data: error_message    type string,
            auxiliary_string type string.

      error_message = 'Migration currently locked by user &, hence cannot be undone'(024).
      auxiliary_string = lock_owner.
      replace '&' with auxiliary_string into error_message.
      raise exception new cx_migration_error( i_error_message = error_message ).

    endif.

    get time stamp field migration_log-undone_at.

    if migration_log-undone_at = migration_log-last_step_completed_at.
      wait up to 1 seconds.
    endif.

    delete from satc_ci_exempt
      where    chkclass = c_target_check_class
           and xx_hint  = migration_handler=>c_migration_hint.

    migration_handler=>log_migration_action( i_action = c_migration_action-undo_migration ).

    migration_handler=>unlock_migration( ).

  endmethod.


  method get_migratable_exemption_count.

    data(mapping_rules) = get_mapping_rules( i_omit_successor_codes = abap_true ). "Successor codes not relevant for selecting the migratable exemptions

    loop at mapping_rules-mapping_rules_4_check_codes assigning field-symbol(<mapping_rules_4_check_codes>).

      loop at <mapping_rules_4_check_codes>-mapping_rule_check_codes-source_check_codes assigning field-symbol(<source_check_code>).

        get_migratable_exemptions(
        exporting
          i_source_check_code           = <source_check_code>
          i_mapping_rules_4_check_codes = <mapping_rules_4_check_codes>
        importing
          e_total_migratable_exemptions = data(total_migratable_exemptions) ).

        result += total_migratable_exemptions.

      endloop.

    endloop.

  endmethod.


  method get_migrated_exemption_count.

    select count( * ) from satc_ci_exempt into result
      where    chkclass = c_target_check_class
           and xx_hint = migration_handler=>c_migration_hint.

  endmethod.


  method migratable_exemption_may_exist.

    select single @abap_true from satc_ci_exempt
        where    chkclass in @source_check_classes
             and deleted  = @abap_false
             and state    = @if_satc_ci_exemption_root=>co_exemption_state-approved
             and (   valid_until is initial
                  or valid_until >= @today )
        into @result.

  endmethod.


  method get_migratable_exemptions.

    clear e_migratable_exemptions.
    clear e_total_migratable_exemptions.

    if e_migratable_exemptions is requested.

      select * from satc_ci_exempt
          where    chkcode  =  @i_source_check_code-check_code
               and objtype  in @i_mapping_rules_4_check_codes-mapping_rule_check_codes-object_type_range
               and chkclass in @source_check_classes
               and deleted  =  @abap_false
               and state    =  @if_satc_ci_exemption_root=>co_exemption_state-approved
               and (   valid_until is initial
                    or valid_until >= @today )
      into table @e_migratable_exemptions.
      e_total_migratable_exemptions = lines( e_migratable_exemptions ).

    else.

      select count( * ) from satc_ci_exempt
          where    chkcode  =  @i_source_check_code-check_code
               and objtype  in @i_mapping_rules_4_check_codes-mapping_rule_check_codes-object_type_range
               and chkclass in @source_check_classes
               and deleted  = @abap_false
               and state    = @if_satc_ci_exemption_root=>co_exemption_state-approved
               and (   valid_until is initial
                    or valid_until >= @today )
      into @e_total_migratable_exemptions.

    endif.

  endmethod.


  method do_initialization.

    data: initialization_already_called type abap_bool,
          initialized_language          type sy-langu,
          initialized_program           type sy-cprog.

    import p1 = initialization_already_called
           p2 = initialized_language
           p3 = initialized_program
           from memory id c_memory_id_for_initialization.

    if    initialization_already_called = abap_true
      and initialized_language          = sy-langu
      and initialized_program           = sy-cprog.

      return.

    endif.

    data: error_message             type string,
          no_run_or_undo_migrations like error_message.

    if not is_authorized(
             exporting
               i_for_run_or_undo_migrations = abap_true
             importing
               e_error_message              = no_run_or_undo_migrations ).

      if is_authorized(
           exporting
             i_for_run_or_undo_migrations = abap_false
           importing
             e_error_message              = error_message ).

        error_message = no_run_or_undo_migrations.

      endif.

      message error_message type 'S' display like 'E'.
      return.

    endif.

    initialization_already_called = abap_true.
    initialized_language          = sy-langu.
    initialized_program           = sy-cprog.

    export p1 = initialization_already_called
           p2 = initialized_language
           p3 = initialized_program
           to memory id c_memory_id_for_initialization.

    constants: c_original_language type sy-langu value 'E'.

    data: original_texts type ty_textpool.

    read textpool sy-cprog into original_texts language c_original_language.

*Minimally required texts:
*  Row  ID  KEY       ENTRY                                                        LENGTH
*  ======================================================================================
*  21   I   RST       Restrictions on Generation of Clean Core Exemptions          80
*  22   R             Migrate Cloud Readiness Exemptions to Clean Core Exemptions  59
*  23   S   EXCLSUCC          Omit Successor Codes                                 28
*  24   S   INCLSUCC          No Restrictions                                      23
*  25   S   MIGRATE           Run Migration                                        21
*  26   S   SUMMARY           Show Migration Information                           34
*  27   S   UNDO              Undo Migration                                       22

    data: required_text like line of original_texts.
    data(insert_changed_textpool) = abap_false.

    "Add text element required for selection screen (all other missing text elements will be taken over from the program's implementation.
    required_text-id = 'I'.
    required_text-key = 'RST'.
    required_text-entry = 'Restrictions on Generation of Clean Core Exemptions'(RST).
    required_text-length = 80 ##NUMBER_OK.

    migration_handler=>adjust_texts_if_required(
      exporting
        i_required_text           = required_text
      changing
        c_original_texts          = original_texts
        c_insert_changed_textpool = insert_changed_textpool ).

    "Add selection texts
    required_text-id = 'S'.

    do 5 times.

      case sy-index.

        when 1.
          required_text-key    = 'EXCLSUCC'.
          required_text-entry  = 'Omit Successor Codes'(RSO).
          required_text-length = 28 ##NUMBER_OK.

        when 2.
          required_text-key    = 'INCLSUCC'.
          required_text-entry  = 'No Restrictions'(RSN).
          required_text-length = 23 ##NUMBER_OK.

        when 3.
          required_text-key    = 'MIGRATE'.
          required_text-entry  = 'Run Migration'(MIG).
          required_text-length = 21 ##NUMBER_OK.

        when 4.
          required_text-key    = 'SUMMARY'.
          required_text-entry  = 'Show Migration Information'(SUM).
          required_text-length = '34' ##NUMBER_OK.

        when 5.
          required_text-key    = 'UNDO'.
          required_text-entry  = 'Undo Migration'(UND).
          required_text-length = 22 ##NUMBER_OK.

      endcase.

      required_text-entry = |        { required_text-entry }|. "For selection parameter texts 8 leading spaces are required

      migration_handler=>adjust_texts_if_required(
        exporting
          i_required_text           = required_text
        changing
          c_original_texts          = original_texts
          c_insert_changed_textpool = insert_changed_textpool ).
    enddo.

    "Add program description
    required_text-id     = 'R'.
    required_text-key    = space.
    required_text-entry  = 'Migrate Cloud Readiness Exemptions to Clean Core Exemptions'(RPD).
    required_text-length = 59 ##NUMBER_OK.

    migration_handler=>adjust_texts_if_required(
      exporting
        i_required_text           = required_text
      changing
        c_original_texts          = original_texts
        c_insert_changed_textpool = insert_changed_textpool ).

    if sy-langu = c_original_language.

      if insert_changed_textpool = abap_true.
        data(required_texts) = original_texts.
      else.
        return.
      endif.

    else.

      read textpool sy-cprog into required_texts language sy-langu.

      if required_texts is initial.

        required_texts = original_texts.
        insert_changed_textpool = abap_true.

      else.

        delete required_texts where entry is initial.

        loop at required_texts assigning field-symbol(<required_texts>).
          read table original_texts transporting no fields with key id = <required_texts>-id key = <required_texts>-key.

          if sy-subrc <> 0.
            delete required_texts.
          endif.

        endloop.

        loop at original_texts assigning field-symbol(<original_text>).

          read table required_texts transporting no fields with key id = <original_text>-id key = <original_text>-key.

          if sy-subrc <> 0.

            insert <original_text> into table required_texts.
            insert_changed_textpool = abap_true.

          endif.

        endloop.

      endif.

    endif.

    if insert_changed_textpool = abap_true.

      insert textpool sy-cprog from required_texts language sy-langu.
      data: warning type string.
      warning = 'Missing or outdated texts supplemented in English but visible only after program restart'(014).
      message warning type 'W' display like 'E'.

    endif.

  endmethod.


  method get_migration_comment.

    data(migration_log) = read_migration_log( ).

    if    migration_log is initial
     or migration_log-started_at is initial.

      return.

    endif.

    result = 'Generated from Cloud Readiness exemption by program &1, started by user &2 on &3 at &4'(025).
    data: auxiliary_string type string.
    auxiliary_string = sy-cprog.
    replace '&1' with auxiliary_string into result.

    auxiliary_string = migration_log-run_by.
    replace '&2' with auxiliary_string into result.

    migration_handler=>derive_date_and_time(
    exporting
      i_timestamp = migration_log-started_at
    importing
      e_date      = data(migration_date)
      e_time      = data(migration_time) ).
    auxiliary_string = migration_date.
    replace '&3' with auxiliary_string into result.

    auxiliary_string = migration_time.
    replace '&4' with auxiliary_string into result.

    result = |### { result } ###|.

  endmethod.


  method derive_migrated_assessment.

    data(migration_comment) = get_migration_comment( ).

    if migration_comment is initial.
      result = i_assessment.
    else.
      result = |{ migration_comment } { i_assessment }|.
    endif.

  endmethod.


  method is_authorized.

    clear e_error_message.

    result = may_run_or_undo_migrations.

    if result = abap_true.

      "Authorization to run or undo migrations must suffice for reading migration information, too
      return.

    endif.

    if i_for_run_or_undo_migrations = abap_true.

      e_error_message = 'No authorization to run or undo migrations'(002).

    else.

      result = may_read_migration_information.

      if result = abap_false.

        e_error_message = 'No authorization to use program &'(003).
        data: auxiliary_string type string.
        auxiliary_string = sy-cprog.
        replace '&' with auxiliary_string into e_error_message.

      endif.

    endif.

  endmethod.


  method adjust_texts_if_required.

    read table c_original_texts assigning field-symbol(<original_text>)
      with key id  = i_required_text-id
               key = i_required_text-key.

    if sy-subrc <> 0.

      insert i_required_text into table c_original_texts.

    elseif <original_text>-entry = i_required_text-entry.

      "Length-only differences are negligible. If compared here, too, we would have to distinguish length-only changes from mere text changes.
      "Otherwise, the user would be reported that missing textes were supplemented in English, although only length adjustements were made.
      return.

    else.

      <original_text>-entry  = i_required_text-entry.
      <original_text>-length = i_required_text-length.

    endif.

    c_insert_changed_textpool = abap_true.

  endmethod.

endclass.

class tc_migration_handler definition final for testing
  duration short risk level harmless.


  private section.
    class-data:
      sql_test_environment type ref to if_osql_test_environment.

    class-methods:
      class_setup.

    data:
      dummy_source_exemption_count type i value 2,
      dummy_target_exemption_count type i value 6.

    methods:
      setup,
      teardown,
      get_migratable_exemptions
        importing
          i_rule_index  type i optional
        returning
          value(result) type migration_handler=>ty_exemptions,
      build_migratable_exemptions
        importing
          i_mapping_rule_4_check_codes type migration_handler=>ty_mapping_rule_4_check_codes
        exporting
          e_result                     type migration_handler=>ty_exemptions
        changing
          c_migratable_exemption       type migration_handler=>ty_exemption,
      prepare_exemptions_for_undo
        importing
          i_migration_log type migration_handler=>ty_migration_log
        returning
          value(result)   type migration_handler=>ty_exemptions,
      get_mapping_rules              for testing,
      get_migratable_exemption_count for testing,
      get_migrated_exemption_count   for testing,
      derive_clean_core_exemptions   for testing,
      migration_locking              for testing,
      do_migration                   for testing,
      undo_migration                 for testing.

endclass.

class tc_migration_handler implementation.

  method class_setup.

    data: error_message type string.

    if not migration_handler=>is_authorized(
          exporting
            i_for_run_or_undo_migrations = abap_true
          importing
            e_error_message              = error_message ).

      cl_abap_unit_assert=>abort( msg = error_message ).

    endif.

    try.
        data: lock_owner type sy-uname.
        data(migration_is_locked) = migration_handler=>migration_is_locked( importing e_lock_owner = lock_owner ).

        if migration_is_locked = abap_true.
          cl_abap_unit_assert=>abort( msg = |Migration currently locked by user { lock_owner }| ).
        endif.

        sql_test_environment = cl_osql_test_environment=>create( i_dependency_list = value #( ( 'SATC_AC_STATE'   )
                                                                                              ( 'SATC_AC_S_STATE' )
                                                                                              ( 'SATC_CI_EXEMPT'  ) ) ).
      catch cx_migration_error into data(migration_error).
        cl_abap_unit_assert=>abort( msg = migration_error->get_text( ) ).
    endtry.

  endmethod.


  method setup.
    sql_test_environment->clear_doubles( ).
  endmethod.


  method teardown.

    data(migration_log) = migration_handler=>read_migration_log( ).

    if   migration_log is initial
      or migration_log-finished = abap_true.

      return.

    endif.

    try.
        data: lock_owner type sy-uname.

        if    migration_handler=>migration_is_locked( importing e_lock_owner = lock_owner )
          and lock_owner = sy-uname.

          migration_handler=>unlock_migration( ).

        endif.

      catch cx_migration_error into data(migration_error).
        cl_abap_unit_assert=>fail( msg = migration_error->get_text( )
                                   level = if_abap_unit_constant=>severity-low ).
    endtry.

  endmethod.


  method get_migratable_exemptions.

    data: migratable_exemption type migration_handler=>ty_exemption.

    data(mapping_rules) = migration_handler=>get_mapping_rules( i_omit_successor_codes = abap_true ).

    migratable_exemption-appl_comment     = 'Comment by requester'.
    migratable_exemption-appr_comment     = 'Comment by Approver'.
    migratable_exemption-chkclass         = 'CL_CLS_CI_CHECK_E_ONPR_CLOUDIF'.
    migratable_exemption-checksum_version = migration_handler=>c_target_checksum_version - 1.
    migratable_exemption-valid_until      = sy-datum.
    migratable_exemption-last_changed     = migratable_exemption-valid_until - 1.
    migratable_exemption-appr_last        = migratable_exemption-last_changed - 1.
    migratable_exemption-appl_last        = migratable_exemption-appr_last - 1.
    migratable_exemption-state            = if_satc_ci_exemption_root=>co_exemption_state-approved.

    do.

      assign component sy-index of structure migratable_exemption to field-symbol(<field>).

      if sy-subrc <> 0.
        exit.
      endif.

      if <field> is not initial.
        continue.
      endif.

      data(type_description) = cl_abap_typedescr=>describe_by_data( <field> ).

      case type_description->type_kind.

        when   cl_abap_typedescr=>typekind_char
            or cl_abap_typedescr=>typekind_clike
            or cl_abap_typedescr=>typekind_csequence.
          translate <field> using ' B'.

        when others.
          <field> = 9.

      endcase.

    enddo.

    clear migratable_exemption-exemption_id.
    clear migratable_exemption-deleted.

    if i_rule_index is not supplied.

      loop at mapping_rules-mapping_rules_4_check_codes assigning field-symbol(<mapping_rule_4_check_codes>).

        build_migratable_exemptions(
        exporting
            i_mapping_rule_4_check_codes = <mapping_rule_4_check_codes>
          importing
            e_result = result
          changing
            c_migratable_exemption = migratable_exemption ).

      endloop.

    else.

      read table mapping_rules-mapping_rules_4_check_codes index i_rule_index assigning <mapping_rule_4_check_codes>.
      build_migratable_exemptions(
        exporting
            i_mapping_rule_4_check_codes = <mapping_rule_4_check_codes>
        importing
          e_result = result
        changing
          c_migratable_exemption = migratable_exemption ).

    endif.

  endmethod.


  method get_mapping_rules.

    data: omit_successor_codes           type abap_bool,
          actual_mapping_rules           type migration_handler=>ty_mapping_rules,
          mapping_rls_with_successors    type migration_handler=>ty_mapping_rules,
          mapping_rls_without_successors like mapping_rls_with_successors.

    do 3 times.

      case sy-index.

        when 1.
          omit_successor_codes = abap_false.

        when 2.
          mapping_rls_with_successors = actual_mapping_rules.
          omit_successor_codes = abap_true.

        when 3.
          mapping_rls_without_successors = actual_mapping_rules.
          omit_successor_codes = abap_false.
          data(compare_mapping_rules) = abap_true.

      endcase.

      actual_mapping_rules = migration_handler=>get_mapping_rules( i_omit_successor_codes = omit_successor_codes ).

      cl_abap_unit_assert=>assert_equals( act = lines( actual_mapping_rules-mapping_rules_4_check_codes )
                                          exp = 8 ).

      if compare_mapping_rules = abap_true.

        loop at mapping_rls_with_successors-mapping_rules_4_check_codes assigning field-symbol(<mpng_rule_with_successors>).

          cl_abap_unit_assert=>assert_equals( act = <mpng_rule_with_successors>-index
                                              exp = sy-tabix ).

          if sy-tabix < 5.
            cl_abap_unit_assert=>assert_not_initial( act = <mpng_rule_with_successors>-mapping_rule_check_codes-object_type_range ).
          else.
            cl_abap_unit_assert=>assert_initial( act = <mpng_rule_with_successors>-mapping_rule_check_codes-object_type_range ).
          endif.

          cl_abap_unit_assert=>assert_not_initial( act = <mpng_rule_with_successors>-mapping_rule_check_codes-source_check_codes ).
          cl_abap_unit_assert=>assert_not_initial( act = <mpng_rule_with_successors>-mapping_rule_check_codes-target_check_codes ).

          loop at <mpng_rule_with_successors>-mapping_rule_check_codes-target_check_codes assigning field-symbol(<target_check_code>).

            if <target_check_code> cs '_SUC'.
              delete <mpng_rule_with_successors>-mapping_rule_check_codes-target_check_codes.
            endif.

          endloop.

          read table mapping_rls_without_successors-mapping_rules_4_check_codes index sy-tabix assigning field-symbol(<mpng_rule_without_successors>).
          cl_abap_unit_assert=>assert_equals( act = <mpng_rule_with_successors>
                                              exp = <mpng_rule_without_successors> ).
        endloop.

      endif.

    enddo.

  endmethod.


  method get_migratable_exemption_count.

    do 4 times.

      case sy-index.

        when 1.
          data(migratable_exemptions) = get_migratable_exemptions( ).

          loop at migratable_exemptions assigning field-symbol(<migratable_exemptions>).
            <migratable_exemptions>-exemption_id = sy-tabix.
          endloop.

          data(exemptions_2_be_inserted) = migratable_exemptions.
          data(expected_total) = lines( migratable_exemptions ).

        when 2.

          exemptions_2_be_inserted = migratable_exemptions.

          loop at exemptions_2_be_inserted assigning <migratable_exemptions>.
            <migratable_exemptions>-deleted = abap_true.
          endloop.

          clear expected_total.

        when 3.

          exemptions_2_be_inserted = migratable_exemptions.

          loop at exemptions_2_be_inserted assigning <migratable_exemptions>.
            clear <migratable_exemptions>-state.
          endloop.

        when 4.

          exemptions_2_be_inserted = migratable_exemptions.

          data(yesterday) = sy-datum - 1.

          loop at exemptions_2_be_inserted assigning <migratable_exemptions>.
            <migratable_exemptions>-valid_until = yesterday.
          endloop.

      endcase.

      sql_test_environment->clear_doubles( ).
      insert satc_ci_exempt from table exemptions_2_be_inserted.

      data(actual_total) = migration_handler=>get_migratable_exemption_count( ).
      cl_abap_unit_assert=>assert_equals( act = actual_total
                                          exp = expected_total ).
    enddo.

  endmethod.


  method get_migrated_exemption_count.

    do 2 times.

      case sy-index.

        when 1.
          data: expected_count type i value 0.

        when 2.

          data(prepared_exemptions) = prepare_exemptions_for_undo( i_migration_log = value #( migration_id = cl_satc_uuid_svc=>create_id( ) ) ).

          loop at prepared_exemptions transporting no fields
            where    chkclass = migration_handler=>c_target_check_class
                 and xx_hint = migration_handler=>c_migration_hint.

            expected_count += 1.

          endloop.

      endcase.

      cl_abap_unit_assert=>assert_equals( act = migration_handler=>get_migrated_exemption_count( )
                                          exp = expected_count ).
    enddo.

  endmethod.


  method derive_clean_core_exemptions.

    data: rule_index          type i,
          source_exemptions   type migration_handler=>ty_exemptions,
          expected_exemption  like line of source_exemptions,
          target_exemptions   like source_exemptions,
          expected_exemptions like target_exemptions.

    data(mapping_rules) = migration_handler=>get_mapping_rules( i_omit_successor_codes = abap_true ).
    data(yesterday) = migration_handler=>today - 1.

    do.

      insert initial line into table target_exemptions.

      case sy-index.

        when 1.
          clear source_exemptions.

        when 2.
          insert initial line into table source_exemptions.

        when 3.
          "Exemptions with non-matching check class are ignored
          data(migratable_exemptions) = get_migratable_exemptions( ).
          source_exemptions = migratable_exemptions.

          loop at source_exemptions assigning field-symbol(<source_exemption>).
            shift <source_exemption>-chkclass by 1 places left.
          endloop.

        when 4.
          "Exemptions with non-matching check codes are ignores
          source_exemptions = migratable_exemptions.

          loop at source_exemptions assigning <source_exemption>.
            shift <source_exemption>-chkcode by 1 places left.
          endloop.

        when 5.
          "Exemptions with non-initial attribute DELETED are ignored, hence in particular archived exemptions,
          source_exemptions = migratable_exemptions.

          loop at source_exemptions assigning <source_exemption>.
            <source_exemption>-deleted = abap_true.
          endloop.

        when 6.
          "Non-approved exemptions are ignored
          source_exemptions = migratable_exemptions.

          loop at source_exemptions assigning <source_exemption>
            where state = if_satc_ci_exemption_root=>co_exemption_state-approved.

            shift <source_exemption>-state by 1 places left.

          endloop.

        when 7.
          "Outdated exemptions are ignored
          source_exemptions = migratable_exemptions.

          loop at source_exemptions assigning <source_exemption>
            where   valid_until is initial
                 or valid_until >= migration_handler=>today.

            <source_exemption>-valid_until = yesterday.

          endloop.

        when others.
          rule_index += 1.
          read table mapping_rules-mapping_rules_4_check_codes index rule_index assigning field-symbol(<mapping_rule_4_check_codes>).

          if sy-subrc <> 0.
            exit.
          endif.

          source_exemptions = get_migratable_exemptions( i_rule_index = rule_index ).
          cl_abap_unit_assert=>assert_not_initial( act = source_exemptions ).

          clear expected_exemptions.

          loop at source_exemptions into expected_exemption
            where objtype in <mapping_rule_4_check_codes>-mapping_rule_check_codes-object_type_range.

            read table <mapping_rule_4_check_codes>-mapping_rule_check_codes-source_check_codes
              with key check_code = expected_exemption-chkcode
                transporting no fields.

            if sy-subrc <> 0.
              continue.
            endif.

            expected_exemption-chkclass = migration_handler=>c_target_check_class.
            expected_exemption-checksum_version = migration_handler=>c_target_checksum_version.

            loop at <mapping_rule_4_check_codes>-mapping_rule_check_codes-target_check_codes into expected_exemption-chkcode.
              insert expected_exemption into table expected_exemptions.
            endloop.

          endloop.

      endcase.

      migration_handler=>derive_clean_core_xmpts(
        exporting
          i_source_exemptions    = source_exemptions
          i_omit_successor_codes = abap_true
        receiving
          result                 = target_exemptions ).

      sort target_exemptions.                          "#EC CI_SORTLOOP
      sort expected_exemptions.                        "#EC CI_SORTLOOP
      cl_abap_unit_assert=>assert_equals( act = target_exemptions
                                          exp = expected_exemptions ).
    enddo.

  endmethod.


  method build_migratable_exemptions.

    clear e_result.

    loop at i_mapping_rule_4_check_codes-mapping_rule_check_codes-source_check_codes assigning field-symbol(<source_check_code>).

      c_migratable_exemption-chkcode = <source_check_code>.
      c_migratable_exemption-checksum = sy-tabix.

      if i_mapping_rule_4_check_codes-mapping_rule_check_codes-object_type_range is initial.

        c_migratable_exemption-objtype = 'ANOT'.
        c_migratable_exemption-objname = cl_satc_uuid_svc=>create_id( ).
        insert c_migratable_exemption into table e_result.

      else.

        loop at i_mapping_rule_4_check_codes-mapping_rule_check_codes-object_type_range assigning field-symbol(<object_type_range_line>) where sign = 'I'.

          c_migratable_exemption-objtype = <object_type_range_line>-low.
          c_migratable_exemption-objname = cl_satc_uuid_svc=>create_id( ).
          insert c_migratable_exemption into table e_result.

        endloop.

        if sy-subrc <> 0.

          do.

            c_migratable_exemption-objtype = |OT{ sy-index }|.

            if c_migratable_exemption-objtype in i_mapping_rule_4_check_codes-mapping_rule_check_codes-object_type_range.

              c_migratable_exemption-objname = cl_satc_uuid_svc=>create_id( ).
              insert c_migratable_exemption into table e_result.
              exit.

            endif.

          enddo.

        endif.

      endif.

    endloop.

  endmethod.


  method migration_locking.

    do 4 times.

      case sy-index.

        when 1.
          data(expect_migration_is_locked) = abap_false.

        when 2.
          try.
              migration_handler=>log_migration_action( i_action                 = migration_handler=>c_migration_action-log_migration_step
                                                       i_source_exemption_count = dummy_source_exemption_count
                                                       i_target_exemption_count = dummy_target_exemption_count ).
              expect_migration_is_locked = abap_true.
            catch cx_migration_error into data(migration_error).
              cl_abap_unit_assert=>fail( msg = migration_error->get_text( ) ).
          endtry.

        when 3.
          try.
              migration_handler=>log_migration_action( i_action                 = migration_handler=>c_migration_action-finish_migration
                                                       i_source_exemption_count = dummy_source_exemption_count
                                                       i_target_exemption_count = dummy_target_exemption_count ).
              expect_migration_is_locked = abap_false.
            catch cx_migration_error into migration_error.
              cl_abap_unit_assert=>fail( msg = migration_error->get_text( ) ).
          endtry.

        when 4.
          try.
              migration_handler=>log_migration_action( i_source_exemption_count = dummy_source_exemption_count
                                                       i_target_exemption_count = dummy_target_exemption_count ).
              cl_abap_unit_assert=>fail( msg = 'Logging of already completed migration must not be possible' ).
            catch cx_migration_error into migration_error.
              data(error_message) = migration_error->get_text( ) ##NEEDED. "Could facilitate potential error analysis
              expect_migration_is_locked = abap_false.
          endtry.

      endcase.

      try.
          data: lock_owner type sy-uname.
          data(migration_is_locked) = migration_handler=>migration_is_locked( importing  e_lock_owner = lock_owner ).
          cl_abap_unit_assert=>assert_equals( act = migration_is_locked
                                              exp = expect_migration_is_locked ).

          if expect_migration_is_locked = abap_true.

            cl_abap_unit_assert=>assert_equals( act = lock_owner
                                                exp = sy-uname ).
          endif.

        catch cx_migration_error into migration_error.
          cl_abap_unit_assert=>fail( msg = migration_error->get_text( ) ).
      endtry.

    enddo.

  endmethod.


  method do_migration.

    data: migratable_exemptions        type migration_handler=>ty_exemptions,
          exemptions_before_migration  like migratable_exemptions,
          exp_total_created_exemptions type i,
          rule_index                   type i.

    do 4 times.

      try.
          case sy-index.

            when 1.
              data(migration_must_fail) = abap_false.
              data(omit_successor_codes) = abap_true.
              data(migratable_exemptions_exist) = abap_false.

            when 2.
              "Migration cannot be repeated, unless it has been undone
              migration_must_fail = abap_true.
              migratable_exemptions_exist = abap_true.
              omit_successor_codes = abap_false.
              data(failure_message) = 'Migration has already been run. Undo it, if you want to run it again'.

            when 3.
              migration_handler=>undo_migration( ).
              migration_must_fail = abap_false.
              omit_successor_codes = abap_true.

            when 4.
              migration_handler=>undo_migration( ).
              migration_must_fail = abap_false.
              try.
                  migration_handler=>undo_migration( ).
                  cl_abap_unit_assert=>fail( msg = 'An already undone migration cannot be undone again' ).
                catch cx_migration_error into data(migration_error).
                  data(error_message) = migration_error->get_text( ). "Could facilitate potential error analysis
              endtry.

          endcase.

          if exemptions_before_migration is not initial.

            clear exemptions_before_migration.
            sql_test_environment->clear_doubles( ).

          endif.

          clear exp_total_created_exemptions.

          if migratable_exemptions_exist = abap_true.

            data(mapping_rules) = migration_handler=>get_mapping_rules( i_omit_successor_codes = omit_successor_codes ).

            do 2 times.

              case sy-index.

                when 1.
                  rule_index = 7.

                when 2.
                  rule_index = 8.

              endcase.

              migratable_exemptions = get_migratable_exemptions( i_rule_index = rule_index ).
              insert lines of migratable_exemptions into table exemptions_before_migration.
              exp_total_created_exemptions += lines( migratable_exemptions ) * lines( mapping_rules-mapping_rules_4_check_codes[ rule_index ]-mapping_rule_check_codes-target_check_codes ).

            enddo.

            loop at exemptions_before_migration assigning field-symbol(<exemption>).
              <exemption>-exemption_id = cl_satc_uuid_svc=>create_id( ).
            endloop.

            insert satc_ci_exempt from table exemptions_before_migration.

          endif.

          migration_handler=>do_migration( i_omit_successor_codes = omit_successor_codes ).

          if migration_must_fail = abap_true.
            cl_abap_unit_assert=>fail( msg = failure_message ).
          elseif exemptions_before_migration is initial.

            select count( * ) from satc_ci_exempt into @data(total_exemption_count). "#EC CI_NOWHERE
            cl_abap_unit_assert=>assert_initial( act = total_exemption_count ).

          else.

            data(migration_log) = migration_handler=>read_migration_log( ).
            cl_abap_unit_assert=>assert_equals( act = migration_log-total_source_exemptions
                                                exp = lines( exemptions_before_migration ) ).

            select * from satc_ci_exempt into table @data(generated_exemptions)
              where xx_hint  = @migration_handler=>c_migration_hint.

            cl_abap_unit_assert=>assert_equals( act = lines( generated_exemptions )
                                                exp = exp_total_created_exemptions ).
            cl_abap_unit_assert=>assert_equals( act = migration_log-total_target_exemptions
                                                exp = exp_total_created_exemptions ).

            "Compare migrated exemptions with migratable exemptions
            migratable_exemptions = exemptions_before_migration.

            loop at generated_exemptions assigning field-symbol(<generated_exemption>).

              loop at migratable_exemptions assigning <exemption>
                where objname = <generated_exemption>-objname.

                cl_abap_unit_assert=>assert_equals( act = <generated_exemption>-appr_comment
                                                    exp = migration_handler=>derive_migrated_assessment( <exemption>-appr_comment ) ).

                data(expected_generated_exemption) = <exemption>.
                expected_generated_exemption-exemption_id     = <generated_exemption>-exemption_id.
                expected_generated_exemption-appr_comment     = migration_handler=>derive_migrated_assessment( expected_generated_exemption-appr_comment ).
                expected_generated_exemption-back_pack        = migration_log-migration_id.
                expected_generated_exemption-chkclass         = migration_handler=>c_target_check_class.
                expected_generated_exemption-chkcode          = <generated_exemption>-chkcode.
                expected_generated_exemption-checksum_version = migration_handler=>c_target_checksum_version.
                expected_generated_exemption-prev_state       = space.
                expected_generated_exemption-xx_hint          = migration_handler=>c_migration_hint.
                cl_abap_unit_assert=>assert_equals( act = <generated_exemption>
                                                    exp = expected_generated_exemption ).
                exit.

              endloop.

              cl_abap_unit_assert=>assert_subrc( act = sy-subrc
                                                 exp = 0 ).
            endloop.

            data: exemptions_after_migration like exemptions_before_migration.
            select * from satc_ci_exempt into table exemptions_after_migration. "#EC CI_NOWHERE
            insert lines of generated_exemptions into table exemptions_before_migration.
            sort exemptions_after_migration.           "#EC CI_SORTLOOP
            sort exemptions_before_migration.          "#EC CI_SORTLOOP
            cl_abap_unit_assert=>assert_equals( act = exemptions_before_migration
                                                exp = exemptions_after_migration ).
          endif.

        catch cx_migration_error into migration_error.

          error_message = migration_error->get_text( ).

          if migration_must_fail = abap_false.

            cl_abap_unit_assert=>fail( msg = error_message ).

          else.

            select * from satc_ci_exempt into table exemptions_after_migration. "#EC CI_NOWHERE
            sort exemptions_after_migration.           "#EC CI_SORTLOOP
            sort exemptions_before_migration.          "#EC CI_SORTLOOP
            cl_abap_unit_assert=>assert_equals( act = exemptions_before_migration
                                                exp = exemptions_after_migration ).
          endif.

      endtry.

    enddo.

  endmethod.


  method undo_migration.

    do 4 times.

      try.
          case sy-index.

            when 1.
              data(undo_must_fail) = abap_true.
              data(failure_message) = 'It must not be possible to undo a not yet started migration'.

            when 2.
              migration_handler=>log_migration_action( i_source_exemption_count = dummy_source_exemption_count
                                                       i_target_exemption_count = dummy_target_exemption_count ).
              data(migration_log) = migration_handler=>read_migration_log( ).
              undo_must_fail = abap_true.
              failure_message = 'It must not be possible to undo a locked migration'.
              data(exemptions_before_call_of_undo) = prepare_exemptions_for_undo( migration_log ).

            when 3.
              migration_handler=>log_migration_action( i_action                 = migration_handler=>c_migration_action-finish_migration
                                                       i_source_exemption_count = dummy_source_exemption_count
                                                       i_target_exemption_count = dummy_target_exemption_count ).
              migration_log = migration_handler=>read_migration_log( ).
              exemptions_before_call_of_undo = prepare_exemptions_for_undo( migration_log ).
              undo_must_fail = abap_false.

            when 4.
              migration_handler=>log_migration_action( i_source_exemption_count = dummy_source_exemption_count
                                                       i_target_exemption_count = dummy_target_exemption_count ).
              migration_handler=>log_migration_action( i_action                 = migration_handler=>c_migration_action-finish_migration
                                                       i_source_exemption_count = dummy_source_exemption_count
                                                       i_target_exemption_count = dummy_target_exemption_count ).
              migration_log = migration_handler=>read_migration_log( ).
              exemptions_before_call_of_undo = prepare_exemptions_for_undo( migration_log ).
              data(one_second_after_migration) = cl_abap_tstmp=>add_to_short( secs = 1
                                                                              tstmp = migration_log-last_step_completed_at ).

              loop at exemptions_before_call_of_undo assigning field-symbol(<migrated_exemption>) where xx_hint = migration_handler=>c_migration_hint.

                if sy-tabix = 1.

                  update satc_ci_exempt set last_changed = one_second_after_migration
                    where    exemption_id <> <migrated_exemption>-exemption_id
                         and xx_hint = migration_handler=>c_migration_hint.
                else.
                  <migrated_exemption>-last_changed = one_second_after_migration.
                endif.

              endloop.

              undo_must_fail = abap_false.

          endcase.

          migration_handler=>undo_migration( ).

          if undo_must_fail = abap_true.
            cl_abap_unit_assert=>fail( msg = failure_message ).
          elseif exemptions_before_call_of_undo is not initial.

            data: exemptions_after_call_of_undo like exemptions_before_call_of_undo.
            select * from satc_ci_exempt into table exemptions_after_call_of_undo. "#EC CI_NOWHERE
            delete exemptions_before_call_of_undo where xx_hint = migration_handler=>c_migration_hint.
            sort exemptions_after_call_of_undo.        "#EC CI_SORTLOOP
            sort exemptions_before_call_of_undo.       "#EC CI_SORTLOOP
            cl_abap_unit_assert=>assert_equals( act = exemptions_before_call_of_undo
                                                exp = exemptions_after_call_of_undo ).
          endif.

        catch cx_migration_error into data(migration_error).

          data(error_message) = migration_error->get_text( ).

          if undo_must_fail = abap_false.
            cl_abap_unit_assert=>fail( msg = error_message ).
          elseif exemptions_before_call_of_undo is initial.

            select * from satc_ci_exempt into table exemptions_after_call_of_undo. "#EC CI_NOWHERE
            sort exemptions_after_call_of_undo.        "#EC CI_SORTLOOP
            sort exemptions_before_call_of_undo.       "#EC CI_SORTLOOP
            cl_abap_unit_assert=>assert_equals( act = exemptions_before_call_of_undo
                                                exp = exemptions_after_call_of_undo ).
          endif.

      endtry.

    enddo.

  endmethod.


  method prepare_exemptions_for_undo.

    delete from satc_ci_exempt.                         "#EC CI_NOWHERE

    do 4 times.

      if sy-index = 1.

        data(last_changed) = i_migration_log-last_step_completed_at.
        data(back_pack) = i_migration_log-migration_id.
        data(xx_hint) = migration_handler=>c_migration_hint.

      elseif sy-index = 3.
        data(expected_total_migrated_xmpts) = sy-index - 1.
        get time stamp field last_changed.
        clear back_pack.
        clear xx_hint.

      endif.

      insert value #( exemption_id = cl_satc_uuid_svc=>create_id( )
                      chkclass     = migration_handler=>c_target_check_class
                      last_changed = last_changed
                      back_pack    = back_pack
                      xx_hint      = xx_hint ) into table result.
    enddo.

    insert satc_ci_exempt from table result.
    select count( * ) from satc_ci_exempt into @data(total_exemptions). "#EC CI_NOWHERE
    cl_abap_unit_assert=>assert_equals( act = total_exemptions
                                        exp = lines( result ) ).
    select count( * ) from satc_ci_exempt into @data(total_migrated_exemptions) where xx_hint = @migration_handler=>c_migration_hint.
    cl_abap_unit_assert=>assert_equals( act = total_migrated_exemptions
                                        exp = expected_total_migrated_xmpts ).
  endmethod.

endclass.


initialization.
  migration_handler=>do_initialization( ).


start-of-selection.

  data: error_message type string ##NEEDED.

  if not migration_handler=>is_authorized(
        exporting
          i_for_run_or_undo_migrations = xsdbool( migrate = abap_true or undo = abap_true )
        importing
          e_error_message              = error_message ).
    message error_message type 'S' display like 'E'.
    return.

  endif.

  if not cl_satc_ac_fixed_config=>use_code_inspector_as_flavor( ).

    error_message = 'ATC not configured for use in customer mode'(001).
    message error_message type 'S' display like 'E'.
    return.

  endif.

  case abap_true.

    when summary.

* For logon languages different from English, the subsequent lines can serve for testing the automated text completion
*      if sy-uname = '<User name of tester>'.
*
*        if   sy-cprog <> 'SATC_CLOUD_RDNSS_2_CLN_CORE'
*          or sy-langu <> 'E'.
*
*          "No deletions if logon language the original language and calling program the original program !!!
*          delete from satc_ac_s_state where item_key = 'MIGRATION.CLD_RDNS_2_CLN_CORE'.
*          delete textpool sy-cprog language sy-langu.
*          delete from memory id migration_handler=>c_memory_id_for_initialization.
*
*        endif.
*
*      endif.

      do 2 times.

        data: text             type string ##NEEDED,
              auxiliary_string type string ##NEEDED.

        case sy-index.

          when 1.
            text = 'Migratable Cloud Readiness exemptions: &'(004).
            auxiliary_string = migration_handler=>get_migratable_exemption_count( ).

          when 2.
            text = 'Generated Clean Core exemptions: &'(005).
            auxiliary_string = migration_handler=>get_migrated_exemption_count( ).

        endcase.
        replace '&' with auxiliary_string into text.
        write:/ text.

      enddo.

      skip.

      data(migration_log) = migration_handler=>read_migration_log( ) ##NEEDED.

      if migration_log is initial.

        data: lock_owner type sy-uname ##NEEDED.

        try.

            if migration_handler=>migration_is_locked( importing e_lock_owner = lock_owner ).
              text = 'Very first migration started and currently locked by user &'(021).
              auxiliary_string = lock_owner.
              replace '&' with auxiliary_string into text.
              write:/ text.

            else.
              write:/ 'No migration has been run up to now'(006).
            endif.

          catch cx_migration_error into data(migration_error) ##NEEDED.
            message migration_error type 'S' display like 'E'.
            return.
        endtry.

      else.

        data: execution_date type string ##NEEDED,
              execution_time type string ##NEEDED.

        migration_handler=>derive_date_and_time(
          exporting
            i_timestamp = migration_log-started_at
          importing
            e_date      = execution_date
            e_time      = execution_time ).

        text = 'Migration started on &1 at &2 by user &3'(010).
        replace '&1' in text with execution_date.
        replace '&2' in text with execution_time.
        replace '&3' in text with migration_log-run_by.
        write:/ text.

        text = 'Generation restrictions selected: &'(RSP).

        if migration_log-omit_successor_codes = abap_true.
          auxiliary_string = 'Omit Successor Codes'(RSO).
        else.
          auxiliary_string = 'No Restrictions'(RSN).
        endif.

        replace '&' with auxiliary_string into text.
        write:/ text.

        text = 'Cloud Readiness exemptions migrated: &'(011).
        auxiliary_string = migration_log-total_source_exemptions.
        replace '&' in text with auxiliary_string.
        write:/ text.
        text = 'Clean Core exemptions generated frome these: &'(012).
        auxiliary_string = migration_log-total_target_exemptions.
        replace '&' in text with auxiliary_string.
        write:/ text.

        if migration_log-finished = abap_true.

          migration_handler=>derive_date_and_time(
            exporting
              i_timestamp = migration_log-last_step_completed_at
            importing
              e_date      = execution_date
              e_time      = execution_time ).

          text = 'Migration finished successfully on &1 at &2'(013).
          replace '&1' in text with execution_date.
          replace '&2' in text with execution_time.
          write:/ text.

        else.

          try.

              if migration_handler=>migration_is_locked( importing e_lock_owner = lock_owner ).
                text = 'Migration started and currently locked by user &'(026).
                auxiliary_string = lock_owner.
                replace '&' with auxiliary_string into text.
                write:/ text.
              else.
                write:/ 'Migration neither locked nor marked as finished, hence very likely aborted'(027).
              endif.

            catch cx_migration_error into migration_error.
              message migration_error type 'S' display like 'E'.
              return.

          endtry.

        endif.

        skip.

        if migration_log-undone_at < migration_log-last_step_completed_at.
          write:/ 'Undo the migration in case you want to run it again'(008).
        else.

          migration_handler=>derive_date_and_time(
            exporting
              i_timestamp = migration_log-undone_at
            importing
              e_date      = execution_date
              e_time      = execution_time ).

          text = 'Migration undone by user &1 on &2 at &3'(015).
          auxiliary_string = migration_log-undone_by.
          replace '&1' with auxiliary_string into text.
          replace '&2' in text with execution_date.
          replace '&3' in text with execution_time.
          write:/ text.

          skip.
          write:/ 'If required, you can run the migration again'(016).

        endif.

      endif.

    when migrate.

      try.
          migration_handler=>do_migration( i_omit_successor_codes = exclsucc ).
          message 'Migration finished successfully'(007) type 'S'.
        catch cx_migration_error into migration_error.
          message migration_error type 'S' display like 'E'.
      endtry.

    when undo.

      try.
          migration_handler=>undo_migration( ).
          message 'Migration undone successfully'(009) type 'S'.
        catch cx_migration_error into migration_error.
          message migration_error type 'S' display like 'E'.
      endtry.

  endcase.
