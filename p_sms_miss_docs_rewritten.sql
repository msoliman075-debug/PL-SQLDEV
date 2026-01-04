PROCEDURE p_sms_miss_docs IS
    /*
    Purpose: Check for missing claim documents and send SMS notifications
    Called From: Oracle Forms trigger
    Notes: Processes CLM_DTL and MTR_DTL3 blocks to identify missing documents
           and notify drivers/customers via SMS
    */
    
    -- Variable declarations
    v_miss_doc_exist     NUMBER := 0;
    v_driver_id          VARCHAR2(100);
    v_online_sms_msg     VARCHAR2(5000) := NULL;
    v_lang               VARCHAR2(5) := NULL;
    v_sms_tpmd           VARCHAR2(1);
    v_accident_report_no VARCHAR2(20);
    v_miss_docs_ar       VARCHAR2(300);
    v_miss_docs_en       VARCHAR2(400);
    v_receipt_link       VARCHAR2(1000);
    miss_doc_crsr        SYS_REFCURSOR;
    v_cust_name          VARCHAR2(400);
    v_param_link         VARCHAR2(1000);
    v_final_link         VARCHAR2(1000);
    v_report_name        VARCHAR2(1000);
    v_report_param       VARCHAR2(1000);
    v_miss_doc_cnt       NUMBER := 0;
    
BEGIN
    -- ========================================================
    -- Retrieve SMS configuration settings from app_config
    -- ========================================================
    BEGIN
        SELECT NVL(att1, 'N'),
               NVL(att3, 'N')
        INTO   v_sms_tpmd,
               v_receipt_link
        FROM   edge.app_config ac
        WHERE  ac.app_id = 10750;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            v_sms_tpmd := 'N';
            v_receipt_link := '';
        WHEN OTHERS THEN
            v_sms_tpmd := 'N';
            v_receipt_link := '';
    END;
    
    -- ========================================================
    -- Process all records in CLM_DTL block
    -- ========================================================
    go_block('CLM_DTL');
    first_record;
    
    LOOP
        -- ====================================================
        -- Navigate to MTR_DTL3 block for detail processing
        -- ====================================================
        go_block('mtr_dtl3');
        first_record;
        
        IF form_success THEN
            -- Check if SMS for Third Party Missing Documents is enabled
            IF NVL(v_sms_tpmd, 'N') = 'Y' THEN
                
                LOOP
                    -- ============================================
                    -- For OD (Own Damage) claims, check missing document count
                    -- and update online status accordingly
                    -- ============================================
                    IF :mtr_dtl3.clm_dtl_cover_type = 'OD' THEN
                        BEGIN
                            -- Count missing required documents for this detail
                            SELECT COUNT(1)
                            INTO   v_miss_doc_cnt
                            FROM   csc.clm_req_doc r,
                                   csc.reqdoclist d,
                                   csc.reqdoclist_extra de
                            WHERE  r.req_doc_code = d.req_doc_code(+)
                            AND    r.req_doc_code = de.req_doc_code(+)
                            AND    NVL(d.exclude_from_tracker, 'N') = 'N'
                            AND    NVL(r.chk_req_doc, 'N') = 'Y'
                            AND    NVL(r.chk_rec_doc, 'N') = 'N'
                            AND    r.detail_no = :mtr_dtl3.motor_detail_no;
                            
                            -- Update online status based on missing documents
                            IF v_miss_doc_cnt > 0 THEN
                                :mtr_dtl3.on_line_status := 'D'; -- Documents Missing
                            ELSE
                                -- Only update to Success if not already Sent
                                IF :mtr_dtl3.on_line_status <> 'S' THEN
                                    :mtr_dtl3.on_line_status := 'S'; -- Success
                                END IF;
                            END IF;
                        EXCEPTION
                            WHEN OTHERS THEN
                                NULL; -- Continue processing on error
                        END;
                    END IF;
                    
                    -- ============================================
                    -- Process TP (Third Party) and OD claims with missing documents
                    -- Send SMS only if status changed from previous state
                    -- ============================================
                    IF :mtr_dtl3.clm_dtl_cover_type IN ('TP', 'OD')
                       AND :mtr_dtl3.on_line_status = 'D'
                       AND NVL(:mtr_dtl3.on_line_status, 'X') <> NVL(:mtr_dtl3.old_on_line_status, 'D')
                    THEN
                        -- Debug message (remove in production)
                        msg_alert('Will Execute For : ' || :mtr_dtl3.clm_dtl_cover_type, 'I', FALSE);
                        
                        -- ========================================
                        -- Verify missing documents exist in database
                        -- ========================================
                        BEGIN
                            SELECT COUNT(1)
                            INTO   v_miss_doc_exist
                            FROM   csc.clm_req_doc
                            WHERE  policy_no = :mtr_dtl3.clm_dtl_policy_no
                            AND    claim_no = :mtr_dtl3.clm_dtl_claim_no
                            AND    NVL(detail_no, 0) = NVL(:mtr_dtl3.motor_detail_no, 0)
                            AND    chk_req_doc = 'Y'
                            AND    chk_rec_doc = 'N';
                        EXCEPTION
                            WHEN OTHERS THEN
                                v_miss_doc_exist := 0;
                        END;
                        
                        -- ========================================
                        -- Process SMS notification if missing documents found
                        -- ========================================
                        IF v_miss_doc_exist > 0 THEN
                            
                            -- ====================================
                            -- Determine language and customer/driver name
                            -- ====================================
                            BEGIN
                                IF :mtr_dtl3.clm_dtl_cover_type = 'OD' THEN
                                    -- For Own Damage: get customer details
                                    SELECT DECODE(NVL(corr_type, 'E'), 'A', 'AR', 'EN') corr_type,
                                           CASE NVL(corr_type, 'E')
                                               WHEN 'A' THEN edge.seventoeight(c.a_first_name)
                                               ELSE initcap(c.e_first_name)
                                           END AS cust_name
                                    INTO   v_lang,
                                           v_cust_name
                                    FROM   edge.client c
                                    WHERE  cust_id = :clm.customer_code;
                                ELSE
                                    -- For Third Party: get accident report details
                                    SELECT NVL(os.languagecode, 'AR'),
                                           os.accidentreportnumber
                                    INTO   v_lang,
                                           v_accident_report_no
                                    FROM   edge.online_claim_sub os
                                    WHERE  os.mtrdtlno = NVL(:mtr_dtl3.motor_detail_no, 0);
                                END IF;
                            EXCEPTION
                                WHEN NO_DATA_FOUND THEN
                                    v_lang := 'AR'; -- Default to Arabic
                                WHEN OTHERS THEN
                                    v_lang := 'AR';
                            END;
                            
                            -- ====================================
                            -- Retrieve missing documents list in both languages
                            -- ====================================
                            DECLARE
                                v_docs_en VARCHAR2(100);
                                v_docs_ar VARCHAR2(100);
                                v_par     VARCHAR2(100);
                            BEGIN
                                v_miss_docs_ar := '';
                                v_miss_docs_en := '';
                                
                                -- Call procedure to get missing documents cursor
                                edge.mtr_get_missing_docs(
                                    :mtr_dtl3.motor_detail_no,
                                    :mtr_dtl3.clm_dtl_cover_type,
                                    miss_doc_crsr
                                );
                                
                                -- Build missing documents list
                                LOOP
                                    FETCH miss_doc_crsr INTO v_docs_en, v_docs_ar, v_par, v_par;
                                    EXIT WHEN miss_doc_crsr%NOTFOUND;
                                    
                                    v_miss_docs_en := v_miss_docs_en || CHR(13) || v_docs_en || '. ';
                                    v_miss_docs_ar := v_miss_docs_ar || CHR(13) || v_docs_ar || '. ';
                                END LOOP;
                                
                                CLOSE miss_doc_crsr;
                            EXCEPTION
                                WHEN OTHERS THEN
                                    v_miss_docs_ar := ' ';
                                    v_miss_docs_en := ' ';
                                    IF miss_doc_crsr%ISOPEN THEN
                                        CLOSE miss_doc_crsr;
                                    END IF;
                            END;
                            
                            -- ====================================
                            -- Generate receipt link URL
                            -- ====================================
                            v_report_name := 'onlie_receipt';
                            v_report_param := '&' || :mtr_dtl3.motor_detail_no;
                            v_param_link := v_receipt_link || v_report_name || v_report_param;
                            
                            -- Authenticate and get final URL
                            tajcrs.authenticate_url(v_param_link, v_final_link);
                            
                            -- ====================================
                            -- Build SMS message based on claim type and language
                            -- ====================================
                            v_online_sms_msg := NULL;
                            
                            IF :mtr_dtl3.clm_dtl_cover_type = 'TP' THEN
                                -- Third Party claim message
                                IF v_lang = 'EN' THEN
                                    v_online_sms_msg := edge.sms_msg_const(
                                        6781,
                                        'E',
                                        :mtr_dtl3.arabic_driver_name || CHR(10),
                                        :mtr_dtl3.motor_detail_no || '/' || :mtr_dtl3.clm_dtl_claim_no,
                                        :params.case_no,
                                        NVL(v_miss_docs_en, ' ') || CHR(10),
                                        v_final_link || CHR(10),
                                        '',
                                        ''
                                    );
                                ELSE
                                    v_online_sms_msg := edge.sms_msg_const(
                                        6781,
                                        'A',
                                        :mtr_dtl3.arabic_driver_name || CHR(10),
                                        :mtr_dtl3.motor_detail_no || '/' || :mtr_dtl3.clm_dtl_claim_no,
                                        :params.case_no,
                                        NVL(v_miss_docs_ar, ' ') || CHR(10),
                                        v_final_link || CHR(10),
                                        '',
                                        ''
                                    );
                                END IF;
                                
                            ELSIF :mtr_dtl3.clm_dtl_cover_type = 'OD' THEN
                                -- Own Damage claim message
                                IF :params.p_business_type = 'PL' THEN
                                    -- Personal Line
                                    IF v_lang = 'EN' THEN
                                        v_online_sms_msg := edge.sms_msg_const(
                                            6782,
                                            'E',
                                            v_cust_name || CHR(10),
                                            :mtr_dtl3.motor_detail_no || '/' || :mtr_dtl3.clm_dtl_claim_no,
                                            :mtr_dtl3.registration_no,
                                            NVL(v_miss_docs_en, ' ') || CHR(10),
                                            v_final_link || CHR(10),
                                            '',
                                            ''
                                        );
                                    ELSE
                                        v_online_sms_msg := edge.sms_msg_const(
                                            6782,
                                            'A',
                                            v_cust_name || CHR(10),
                                            :mtr_dtl3.motor_detail_no || '/' || :mtr_dtl3.clm_dtl_claim_no,
                                            :mtr_dtl3.registration_no,
                                            NVL(v_miss_docs_ar, ' ') || CHR(10),
                                            v_final_link || CHR(10),
                                            '',
                                            ''
                                        );
                                    END IF;
                                    
                                ELSIF :params.p_business_type = 'CL' THEN
                                    -- Commercial Line
                                    IF v_lang = 'EN' THEN
                                        v_online_sms_msg := edge.sms_msg_const(
                                            6783,
                                            'E',
                                            v_cust_name || CHR(10),
                                            :mtr_dtl3.motor_detail_no || '/' || :mtr_dtl3.clm_dtl_claim_no,
                                            :mtr_dtl3.registration_no,
                                            NVL(v_miss_docs_en, ' ') || CHR(10),
                                            v_final_link || CHR(10),
                                            '',
                                            ''
                                        );
                                    ELSE
                                        v_online_sms_msg := edge.sms_msg_const(
                                            6783,
                                            'A',
                                            v_cust_name || CHR(10),
                                            :mtr_dtl3.motor_detail_no || '/' || :mtr_dtl3.clm_dtl_claim_no,
                                            :mtr_dtl3.registration_no,
                                            NVL(v_miss_docs_ar, ' ') || CHR(10),
                                            v_final_link || CHR(10),
                                            '',
                                            ''
                                        );
                                    END IF;
                                END IF;
                            END IF;
                            
                            -- ====================================
                            -- Store current online status as old status
                            -- This prevents duplicate SMS sends
                            -- ====================================
                            BEGIN
                                :mtr_dtl3.old_on_line_status := get_item_property('MTR_DTL3.on_line_status', database_value);
                            EXCEPTION
                                WHEN OTHERS THEN
                                    NULL;
                            END;
                            
                            -- ====================================
                            -- Send SMS notification
                            -- Priority: driver_tel_no, then notify_phone
                            -- ====================================
                            IF :mtr_dtl3.driver_tel_no IS NOT NULL THEN
                                edge.send_sms_webservice(
                                    :mtr_dtl3.driver_tel_no,
                                    'Tawuniya',
                                    v_online_sms_msg,
                                    :mtr_dtl3.clm_dtl_policy_no,
                                    bat_user.getlob(:mtr_dtl3.clm_dtl_policy_no),
                                    70,
                                    NULL,
                                    NULL,
                                    :mtr_dtl3.clm_dtl_claim_no,
                                    :mtr_dtl3.motor_detail_no
                                );
                                COMMIT;
                                
                            ELSIF :mtr_dtl3.notify_phone IS NOT NULL THEN
                                edge.send_sms_webservice(
                                    :mtr_dtl3.notify_phone,
                                    'Tawuniya',
                                    v_online_sms_msg,
                                    :mtr_dtl3.clm_dtl_policy_no,
                                    bat_user.getlob(:mtr_dtl3.clm_dtl_policy_no),
                                    70,
                                    NULL,
                                    NULL,
                                    :mtr_dtl3.clm_dtl_claim_no,
                                    :mtr_dtl3.motor_detail_no
                                );
                                COMMIT;
                            END IF;
                            
                        END IF; -- v_miss_doc_exist > 0
                    END IF; -- Cover type and status check
                    
                    -- ========================================
                    -- Navigate to next record in MTR_DTL3 block
                    -- ========================================
                    EXIT WHEN :system.last_record = 'TRUE' OR :mtr_dtl3.motor_detail_no IS NULL;
                    next_record;
                    
                END LOOP; -- MTR_DTL3 records
            END IF; -- SMS enabled check
        END IF; -- form_success
        
        -- ============================================
        -- Navigate to next record in CLM_DTL block
        -- ============================================
        go_block('CLM_DTL');
        EXIT WHEN :system.last_record = 'TRUE';
        next_record;
        
    END LOOP; -- CLM_DTL records
    
EXCEPTION
    WHEN OTHERS THEN
        -- ================================================
        -- Global exception handler for procedure
        -- ================================================
        msg_alert('Error in SMS Miss Documents : ' || SQLERRM, 'I', FALSE);
        
END p_sms_miss_docs;
