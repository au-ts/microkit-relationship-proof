(set-logic ALL)
(set-option :produce-models true)
(set-option :interactive-mode true)

; (set-option :smt.mbqi false)
(set-option :auto_config false)
(set-option :well_sorted_check true)
(set-option :timeout 15000) ; 15 seconds


;
; PRELIMINARIES
;

    (define-sort Word64 () (_ BitVec 64))
    (define-sort Word16 () (_ BitVec 16))
    (declare-datatype Maybe (par (X) ((Nothing) (Just (the X)))))
    (declare-datatype Prod (par (X Y) ((Prod (fst X) (snd Y)))))

;
; KERNEL ABSTRACT SPEC
;

    (define-sort SeL4_ObjRef () Word64)

    (declare-datatype SeL4_CapRights (
        (SeL4_CapRights (cr_read Bool) (cr_write Bool) (cr_grant Bool) (cr_grant_reply Bool))
    ))
    (define-fun RW () SeL4_CapRights (SeL4_CapRights true true false false))
    (define-fun R () SeL4_CapRights (SeL4_CapRights true false false false))
    (define-fun W () SeL4_CapRights (SeL4_CapRights false true false false))
    (define-fun RWGP () SeL4_CapRights (SeL4_CapRights true true false true))

    (define-sort SeL4_IRQ () Word64)

    ; The Haskell spec has an extra field for the seL4 reply cap (it's seems
    ; to me like it was based of the non-MCS version of the cap datatype in
    ; the abstract spec (grep for `datatype cap`)).
    ;
    ; We are targeting MCS however, and the difference is that the reply cap
    ; doesn't have the middle field master: bool.
    ;
    ; As far as I can tell, it was an implementation detail in the kernel (every
    ; active TCB always had a master reply cap, and if they needed to give one
    ; to another TCB, they would mint it) (grep for `setup_reply_master` in non-mcs
    ; abstract spec and read comment above).
    ;
    ; TLDR: we don't have the 'master' field on the reply cap

    (declare-datatype SeL4_Cap (
        (SeL4_Cap_Null)
        (SeL4_Cap_Endpoint (ep_objref SeL4_ObjRef) (ep_badge Word64) (ep_cap_rights SeL4_CapRights))
        (SeL4_Cap_Notification (ntf_objref SeL4_ObjRef) (ntf_badge Word64) (ntf_cap_rights SeL4_CapRights))
        (SeL4_Cap_Reply (rep_objref SeL4_ObjRef) (rep_cap_rights SeL4_CapRights))
        (SeL4_Cap_IRQHandler (irq SeL4_IRQ))
    ))


    (define-sort SeL4_CPtr () Word64)

    (define-sort SeL4_CNode () (Array SeL4_CPtr SeL4_Cap))

    (define-sort SeL4_CSpace () SeL4_CNode)

    (declare-datatype SeL4_MessageInfo (
        (SeL4_MessageInfo (seL4_mi_length Word64)
                          (seL4_mi_extra_caps Word64)
                          (seL4_mi_caps_unwrapped Word64)
                          (seL4_mi_label (_ BitVec 16))))
    )

    (define-fun seL4_MessageInfo_zero () SeL4_MessageInfo
        (SeL4_MessageInfo (_ bv0 64) (_ bv0 64) (_ bv0 64) (_ bv0 16)))

    (define-sort SeL4_Ntfn () Word64)

    (define-sort Mem () (Array Word64 Word64))

    (define-sort KernelOracle () (Prod (Prod SeL4_MessageInfo SeL4_Cap) SeL4_Ntfn))

    (declare-datatype KernelState (
        (KS (ks_thread_cnode SeL4_CNode)
            ; EXTRA: model bound notifications
            (ks_bound_notification (Maybe SeL4_ObjRef))
            ; Mathieu: I suppose we want to allow a thread to hold multiple
            ; reply objects (eventhough right now the microkit never does
            ; this)?
            ;
            ; This is a really weird name
            (ks_reply_obj_has_cap (Array SeL4_Cap Bool))
            ; EXTRA: the kernel oracle also contains the cap to the reply
            ; object you obtain when you receive a ppcall
            (ks_recv_oracle (Maybe KernelOracle))
            ; TODO(rename): shouldn't be called local mem, this can represent
            ; memory in shared memory regions
            (ks_local_mem Mem)
            (ks_local_mem_writable (Array Word64 Bool))
            (ks_local_mem_safe (Array Word64 Bool))
        )
    ))

;
; MICROKIT SPEC
;

    ; microkit constants
    (define-fun INPUT_CAP () SeL4_CPtr (_ bv1 64))
    (define-fun REPLY_CAP () SeL4_CPtr (_ bv4 64))

    (define-fun BASE_OUTPUT_NOTIFICATION_CAP () Word64 (_ bv10 64))
    (define-fun BASE_ENDPOINT_CAP () Word64 (_ bv74 64))
    (define-fun BASE_IRQ_CAP () Word64 (_ bv138 64))


    (declare-datatype PD (
        (PD00) (PD01) (PD02) (PD03) (PD04) (PD05) (PD06) (PD07) (PD08) (PD09)
        (PD10) (PD11) (PD12) (PD13) (PD14) (PD15) (PD16) (PD17) (PD18) (PD19)
        (PD20) (PD21) (PD22) (PD23) (PD24) (PD25) (PD26) (PD27) (PD28) (PD29)
        (PD30) (PD31) (PD32) (PD33) (PD34) (PD35) (PD36) (PD37) (PD38) (PD39)
        (PD40) (PD41) (PD42) (PD43) (PD44) (PD45) (PD46) (PD47) (PD48) (PD49)
        (PD50) (PD51) (PD52) (PD53) (PD54) (PD55) (PD56) (PD57) (PD58) (PD59)
        (PD60) (PD61) (PD62)
    ))

    (declare-datatype Ch (
        (Ch00) (Ch01) (Ch02) (Ch03) (Ch04) (Ch05) (Ch06) (Ch07) (Ch08) (Ch09)
        (Ch10) (Ch11) (Ch12) (Ch13) (Ch14) (Ch15) (Ch16) (Ch17) (Ch18) (Ch19)
        (Ch20) (Ch21) (Ch22) (Ch23) (Ch24) (Ch25) (Ch26) (Ch27) (Ch28) (Ch29)
        (Ch30) (Ch31) (Ch32) (Ch33) (Ch34) (Ch35) (Ch36) (Ch37) (Ch38) (Ch39)
        (Ch40) (Ch41) (Ch42) (Ch43) (Ch44) (Ch45) (Ch46) (Ch47) (Ch48) (Ch49)
        (Ch50) (Ch51) (Ch52) (Ch53) (Ch54) (Ch55) (Ch56) (Ch57) (Ch58) (Ch59)
        (Ch60) (Ch61) (Ch62)
    ))

    (define-sort Inlet () (Prod PD Ch))      ; called PDCh in the Haskell
    (define-sort Comm () (Prod Inlet Inlet))

    (declare-datatype MMR (
        (MMR (mmr_pd PD)
             (mmr_addr Word64)
             (mmr_size Word64)
             (mmr_perm_write Bool)
             (mmr_perm_execute Bool))
    ))

    (define-fun wf_MMR ((r MMR)) Bool (and
        (bvugt (bvadd (mmr_addr r) (mmr_size r)) (mmr_size r))
        (= (_ bv0 64) (bvand (mmr_size r) (_ bv4096 64)))
        (= (_ bv0 64) (bvand (mmr_addr r) (_ bv4096 64)))
    ))


    (define-fun mmr_contains ((addr Word64) (mmr MMR)) Bool (and
        (bvuge addr (mmr_addr mmr))
        (bvule addr (bvadd (mmr_addr mmr) (mmr_size mmr)))
    ))

    (declare-datatype MsgInfo (
        (MI (mi_label Word64)
            (mi_count Word16))
    ))
    (define-fun MsgInfo_zero () MsgInfo (MI (_ bv0 64) (_ bv0 16)))

    ; block seL4_MessageInfo {
    ;     field label 52
    ;     field capsUnwrapped 3
    ;     field extraCaps 2
    ;     field length 7
    ; }
    ; -- seL4/libsel4/mode_include/64/sel4/shared_types.bf
    (define-fun wf_MsgInfo ((msginfo MsgInfo)) Bool (and
        (bvult (mi_label msginfo) (bvshl (_ bv1 64) (_ bv52 64)))
        (bvult (mi_count msginfo) (bvshl (_ bv1 16) (_ bv7 16)))
    ))

    (push)
        (assert (not (and
            (wf_MsgInfo (MI #x000fffffffffffff #x0000))
            (wf_MsgInfo (MI #x000ffffffffffffe (_ bv127 16)))
            (not (wf_MsgInfo (MI #x000ffffffffffffe (_ bv128 16))))
            (not (wf_MsgInfo (MI #x0010000000000000 (_ bv126 16))))
        )))
        (echo "!! wf_MsgInfo check off by one error ")
        (check-sat)
    (pop)

    (define-sort Prio () (_ BitVec 8))

    (declare-datatype MicrokitInvariants (
        (MI (mi_valid_pds (Array PD Bool))
            (mi_valid_inlets (Array Inlet Bool))
            (mi_valid_comms (Array Comm Bool))
            (mi_valid_irqns (Array Inlet Bool))

            ; why a maybe? Passive servers don't have a scheduling context, that
            ; is, they don't necessarily have a priority
            (mi_prio (Array PD (Maybe Prio)))
            (mi_mmrs (Array MMR Bool))
            (mi_provides_pp (Array PD Bool)))
    ))

    ; if inlet=(pd, ch) is a valid inlet, then pd is a valid pd
    (define-fun wf_MicrokitInvariants_1 ((mi MicrokitInvariants)) Bool
        (forall ((inlet Inlet)) (=> (select (mi_valid_inlets mi) inlet)
                                    (select (mi_valid_pds mi) (fst inlet))))
    )

    (define-fun wf_MicrokitInvariants_2 ((mi MicrokitInvariants)) Bool
        (forall ((comm Comm)) (=> (select (mi_valid_comms mi) comm) (and
            (select (mi_valid_inlets mi) (fst comm))
            (select (mi_valid_inlets mi) (snd comm))
        )))
    )

    (define-fun wf_MicrokitInvariants_3 ((mi MicrokitInvariants)) Bool
        (forall ((comm Comm)) (=> (select (mi_valid_comms mi) comm)
                                  (select (mi_valid_comms mi) (Prod (snd comm) (fst comm)))))
    )
    
    (define-fun wf_MicrokitInvariants_4 ((mi MicrokitInvariants)) Bool
        (forall ((comm1 Comm) (comm2 Comm)) (=>
            (select (mi_valid_comms mi) comm1)
            (select (mi_valid_comms mi) comm2)
            (=> (= (fst comm1) (fst comm2))
                (= (snd comm1) (snd comm2)))))
    )

    (define-fun wf_MicrokitInvariants_5 ((mi MicrokitInvariants)) Bool
        (forall ((irq Inlet)) (=> (select (mi_valid_irqns mi) irq)
                                  (select (mi_valid_inlets mi) irq)))
    )

    (define-fun wf_MicrokitInvariants_6 ((mi MicrokitInvariants)) Bool
        (forall ((pd PD)) (=> (select (mi_valid_pds mi) pd)
                              (not (is-Nothing (select (mi_prio mi) pd)))))
    )

    (define-fun wf_MicrokitInvariants_7 ((mi MicrokitInvariants)) Bool
        (forall ((r MMR)) (=> (select (mi_mmrs mi) r) (and (select (mi_valid_pds mi) (mmr_pd r))
                                                           (wf_MMR r))))
    )


    (define-fun wf_MicrokitInvariants ((mi MicrokitInvariants)) Bool (and
        (wf_MicrokitInvariants_1 mi)
        (wf_MicrokitInvariants_2 mi)
        (wf_MicrokitInvariants_3 mi)
        (wf_MicrokitInvariants_4 mi)
        (wf_MicrokitInvariants_5 mi)
        (wf_MicrokitInvariants_6 mi)
        (wf_MicrokitInvariants_7 mi)
        ; TODO: ensure memory safe is actually safe (only current PD can write
        ; to it)
    ))


    (define-fun is_writable_mem ((addr Word64) (mi MicrokitInvariants)) Bool
        (exists ((mmr MMR)) (and
            (wf_MMR mmr)
            (select (mi_mmrs mi) mmr)
            (mmr_contains addr mmr)
            (mmr_perm_write mmr)
        ))
    )

    (define-fun notifications_empty () (Array Ch Bool) ((as const (Array Ch Bool)) false))

    (declare-datatype NextRecv (
        (NR_Notification (flags (Array Ch Bool)))
        (NR_PPCall (ppcall (Prod Ch MsgInfo)))
        (NR_Unknown)
    ))

    (declare-datatype MicrokitState ((MS
        (mi MicrokitInvariants)
        (ms_running_pd PD)
        (ms_recv_oracle NextRecv)
        (ms_unhandled_notified (Array Ch Bool))
        (ms_last_handled_notified (Array Ch Bool))
        (ms_unhandled_ppcall (Maybe (Prod Ch MsgInfo)))
        (ms_unhandled_reply (Maybe MsgInfo))
        (ms_last_handled_reply (Maybe MsgInfo))
    )))

    ; AUTO GENERATED from /home/math2001/work/trustworthy-systems/relation-proof/gen-pd-ch.py
        (define-fun ch2word ((ch Ch)) Word64 (match ch (
            (Ch00 (_ bv0 64))
            (Ch01 (_ bv1 64))
            (Ch02 (_ bv2 64))
            (Ch03 (_ bv3 64))
            (Ch04 (_ bv4 64))
            (Ch05 (_ bv5 64))
            (Ch06 (_ bv6 64))
            (Ch07 (_ bv7 64))
            (Ch08 (_ bv8 64))
            (Ch09 (_ bv9 64))
            (Ch10 (_ bv10 64))
            (Ch11 (_ bv11 64))
            (Ch12 (_ bv12 64))
            (Ch13 (_ bv13 64))
            (Ch14 (_ bv14 64))
            (Ch15 (_ bv15 64))
            (Ch16 (_ bv16 64))
            (Ch17 (_ bv17 64))
            (Ch18 (_ bv18 64))
            (Ch19 (_ bv19 64))
            (Ch20 (_ bv20 64))
            (Ch21 (_ bv21 64))
            (Ch22 (_ bv22 64))
            (Ch23 (_ bv23 64))
            (Ch24 (_ bv24 64))
            (Ch25 (_ bv25 64))
            (Ch26 (_ bv26 64))
            (Ch27 (_ bv27 64))
            (Ch28 (_ bv28 64))
            (Ch29 (_ bv29 64))
            (Ch30 (_ bv30 64))
            (Ch31 (_ bv31 64))
            (Ch32 (_ bv32 64))
            (Ch33 (_ bv33 64))
            (Ch34 (_ bv34 64))
            (Ch35 (_ bv35 64))
            (Ch36 (_ bv36 64))
            (Ch37 (_ bv37 64))
            (Ch38 (_ bv38 64))
            (Ch39 (_ bv39 64))
            (Ch40 (_ bv40 64))
            (Ch41 (_ bv41 64))
            (Ch42 (_ bv42 64))
            (Ch43 (_ bv43 64))
            (Ch44 (_ bv44 64))
            (Ch45 (_ bv45 64))
            (Ch46 (_ bv46 64))
            (Ch47 (_ bv47 64))
            (Ch48 (_ bv48 64))
            (Ch49 (_ bv49 64))
            (Ch50 (_ bv50 64))
            (Ch51 (_ bv51 64))
            (Ch52 (_ bv52 64))
            (Ch53 (_ bv53 64))
            (Ch54 (_ bv54 64))
            (Ch55 (_ bv55 64))
            (Ch56 (_ bv56 64))
            (Ch57 (_ bv57 64))
            (Ch58 (_ bv58 64))
            (Ch59 (_ bv59 64))
            (Ch60 (_ bv60 64))
            (Ch61 (_ bv61 64))
            (Ch62 (_ bv62 64))
        )))
        (define-fun word2ch ((wch Word64)) (Maybe Ch)
          (ite (= wch (_ bv0 64)) (Just Ch00)
          (ite (= wch (_ bv1 64)) (Just Ch01)
          (ite (= wch (_ bv2 64)) (Just Ch02)
          (ite (= wch (_ bv3 64)) (Just Ch03)
          (ite (= wch (_ bv4 64)) (Just Ch04)
          (ite (= wch (_ bv5 64)) (Just Ch05)
          (ite (= wch (_ bv6 64)) (Just Ch06)
          (ite (= wch (_ bv7 64)) (Just Ch07)
          (ite (= wch (_ bv8 64)) (Just Ch08)
          (ite (= wch (_ bv9 64)) (Just Ch09)
          (ite (= wch (_ bv10 64)) (Just Ch10)
          (ite (= wch (_ bv11 64)) (Just Ch11)
          (ite (= wch (_ bv12 64)) (Just Ch12)
          (ite (= wch (_ bv13 64)) (Just Ch13)
          (ite (= wch (_ bv14 64)) (Just Ch14)
          (ite (= wch (_ bv15 64)) (Just Ch15)
          (ite (= wch (_ bv16 64)) (Just Ch16)
          (ite (= wch (_ bv17 64)) (Just Ch17)
          (ite (= wch (_ bv18 64)) (Just Ch18)
          (ite (= wch (_ bv19 64)) (Just Ch19)
          (ite (= wch (_ bv20 64)) (Just Ch20)
          (ite (= wch (_ bv21 64)) (Just Ch21)
          (ite (= wch (_ bv22 64)) (Just Ch22)
          (ite (= wch (_ bv23 64)) (Just Ch23)
          (ite (= wch (_ bv24 64)) (Just Ch24)
          (ite (= wch (_ bv25 64)) (Just Ch25)
          (ite (= wch (_ bv26 64)) (Just Ch26)
          (ite (= wch (_ bv27 64)) (Just Ch27)
          (ite (= wch (_ bv28 64)) (Just Ch28)
          (ite (= wch (_ bv29 64)) (Just Ch29)
          (ite (= wch (_ bv30 64)) (Just Ch30)
          (ite (= wch (_ bv31 64)) (Just Ch31)
          (ite (= wch (_ bv32 64)) (Just Ch32)
          (ite (= wch (_ bv33 64)) (Just Ch33)
          (ite (= wch (_ bv34 64)) (Just Ch34)
          (ite (= wch (_ bv35 64)) (Just Ch35)
          (ite (= wch (_ bv36 64)) (Just Ch36)
          (ite (= wch (_ bv37 64)) (Just Ch37)
          (ite (= wch (_ bv38 64)) (Just Ch38)
          (ite (= wch (_ bv39 64)) (Just Ch39)
          (ite (= wch (_ bv40 64)) (Just Ch40)
          (ite (= wch (_ bv41 64)) (Just Ch41)
          (ite (= wch (_ bv42 64)) (Just Ch42)
          (ite (= wch (_ bv43 64)) (Just Ch43)
          (ite (= wch (_ bv44 64)) (Just Ch44)
          (ite (= wch (_ bv45 64)) (Just Ch45)
          (ite (= wch (_ bv46 64)) (Just Ch46)
          (ite (= wch (_ bv47 64)) (Just Ch47)
          (ite (= wch (_ bv48 64)) (Just Ch48)
          (ite (= wch (_ bv49 64)) (Just Ch49)
          (ite (= wch (_ bv50 64)) (Just Ch50)
          (ite (= wch (_ bv51 64)) (Just Ch51)
          (ite (= wch (_ bv52 64)) (Just Ch52)
          (ite (= wch (_ bv53 64)) (Just Ch53)
          (ite (= wch (_ bv54 64)) (Just Ch54)
          (ite (= wch (_ bv55 64)) (Just Ch55)
          (ite (= wch (_ bv56 64)) (Just Ch56)
          (ite (= wch (_ bv57 64)) (Just Ch57)
          (ite (= wch (_ bv58 64)) (Just Ch58)
          (ite (= wch (_ bv59 64)) (Just Ch59)
          (ite (= wch (_ bv60 64)) (Just Ch60)
          (ite (= wch (_ bv61 64)) (Just Ch61)
          (ite (= wch (_ bv62 64)) (Just Ch62)
          (as Nothing (Maybe Ch))
        ))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))
        (define-fun word_is_valid_ch ((wch Word64)) Bool (is-Just (word2ch wch)))
    ; END OF AUTO GENERATED


;
; Relation MicrokitState
;


    ; There's a mistake in the Haskell here. The input cap is always an
    ; endpoint cap, not a notification cap.
    ;
    ; This is where we will ensure that we have an endpoint cap, and that our
    ; notification cap is bound to our TCB
    (define-fun relation_pd_input_cap ((pd PD) (cap SeL4_Cap)) Bool
        (match cap (
            ((SeL4_Cap_Endpoint objref badge cap_rights) (= cap_rights RWGP))
            ; TODO: we shouldn't have a read right on that cap, but the capDL
            ; generates it that way right now. Fix capDL, and update this
            ; proof.
            (? false)
        ))
    )

    (define-fun relation_inlet_notification_cap ((target_inlet Inlet) (cap SeL4_Cap)) Bool
        (let ((pd (fst target_inlet))
              (ch (snd target_inlet)))
            (match cap (
                ((SeL4_Cap_Notification obj_ref badge cap_rights)
                    (and
                        (= badge (bvshl (_ bv1 64) (ch2word ch)))
                        (= cap_rights RW)
                        ; TODO: we shouldn't have the ability to read that
                        ; notification word (ie. no read cap right), but
                        ; looking at the CapDL, we do have that right => fix
                        ; capDL generation and add this requirement here.
                    )
                )
                (? false)
            ))
        )
    )

    (define-fun relation_inlet_endpoint_cap ((target_inlet Inlet) (cap SeL4_Cap)) Bool
        (let ((target_ch_number (snd target_inlet))
              (one63 (bvshl (_ bv1 64) (_ bv63 64))))
            (match cap (
                ((SeL4_Cap_Endpoint obj_ref badge cap_rights) (and
                    (= badge (bvor one63 (ch2word target_ch_number)))
                    (= cap_rights RWGP)
                    ; TODO: same as above, we shouldn't have read rights
                ))
                (? false)
            ))
        )
    )


    ; DONE
    (define-fun relation_is_irq_cap ((cap SeL4_Cap)) Bool
        (match cap (
            ((SeL4_Cap_IRQHandler ?) true)
            (? false)
        ))
    )

    (define-fun relation_msg_info ((ms_msginfo MsgInfo) (ks_msginfo SeL4_MessageInfo)) Bool
        (and
            (= (mi_label ms_msginfo) (seL4_mi_length ks_msginfo))
            (= (mi_count ms_msginfo) (seL4_mi_label ks_msginfo))
        )
    )

    ; DONE
    (define-fun relation_cap_map ((mi MicrokitInvariants) (pd PD) (ks KernelState)) Bool (and

        ; we must have an endpoint cap
        (relation_pd_input_cap pd (select (ks_thread_cnode ks) INPUT_CAP))

        ; if we have a communication channel
        ;     1. we must have a cap to the notification word
        ;     2. under the right condition, we must have a cap to the endpoint
        (forall ((comm Comm)) (let ((pd/ (fst (fst comm)))
                                    (ch (snd (fst comm)))
                                    (target (snd comm))
                                    (cnode (ks_thread_cnode ks)))
            (and
                (=> (select (mi_valid_comms mi) comm)
                    (= pd pd/)
                    (relation_inlet_notification_cap target
                        (select cnode (bvadd BASE_OUTPUT_NOTIFICATION_CAP (ch2word ch)))))
                (=> (select (mi_valid_comms mi) comm)
                    (= pd pd/)
                    (select (mi_provides_pp mi) (fst target))
                    ; NOTE: it is safe to call `just` on the maybe type, because
                    ; it is an invariant that each priority of all PDs is not
                    ; nothing is not nothing. If we get this wrong, the entire
                    ; (the ...) expressions will evaluate to an _arbitrary_
                    ; value of the same type (SMT-LIB 2, 5.3, definition 8.
                    ; Remark 11 spells it out), and thus would prevent the proof
                    ; from going through.
                    ;
                    ; NOTE: the haskell spec uses >= on the Maybe Num type, but we
                    ; use it on the actual Num. This doesn't matter because we have
                    ; an invariant which ensures that all prio are Just x, not Nothing.
                    ; (again, if we drop this invariant, this proof would fail, see
                    ; point above)
                    (bvult (the (select (mi_prio mi) pd)) (the (select (mi_prio mi) (fst target))))
                    (relation_inlet_endpoint_cap target
                        (select cnode (bvadd BASE_ENDPOINT_CAP (ch2word ch)))))
            )
        ))

        ; must have a cap to the corresponding IRQ notification words
        (forall ((inlet Inlet)) (let ((pd/ (fst inlet))
                                      (ch (snd inlet)))
            (=> (= pd pd/)
                (select (mi_valid_irqns mi) inlet)
                (relation_is_irq_cap (select (ks_thread_cnode ks)
                                        (bvadd BASE_IRQ_CAP (ch2word ch)))))
        ))

    ))
;
    (define-fun relation_mmrs_mem ((mi MicrokitInvariants) (ks KernelState)) Bool
        (and
            (forall ((addr Word64) (mmr MMR) (mmr/ MMR))
                (=> (select (ks_local_mem_safe ks) addr)
                    (select (mi_mmrs mi) mmr)
                    ; if an address is memory safe for _me_ (a PD), then I
                    ; must be the only PD with write access to it. The
                    ; Haskell spec is weird here, and it's not strong enough
                    ; because relation_pd_obj_ref is always true. Instead, we
                    ; express the same idea by ensuring that other regions
                    ; cannot write to our memory safe regions. (I suppose
                    ; that's one the things Zoltan meant when he wrote todo:
                    ; additional clause for writability)
                    (mmr_perm_write mmr)
                    (mmr_perm_write mmr/)
                    (= (mmr_pd mmr) (mmr_pd mmr/))

                    ; maybe: additional clause for writability (this note is
                    ; present in the Haskell spec, and I don't know if there are
                    ; other clauses one would want to add, hence why I'm leaving
                    ; this note)
                )
            )
            (forall ((addr Word64))
                ; WARNING: this is a nested quantifier (there is is a 'there
                ; exists' in the is_writable_mem, which the smt solvers don't
                ; like when trying to prove something false)
                (=
                    (is_writable_mem addr mi)
                    (select (ks_local_mem_writable ks) addr)
                )
            )
        )
    )

    (define-fun relation_reply_cap ((ms MicrokitState) (ks KernelState)) Bool
        (let (
            (reply_cap (select (ks_thread_cnode ks) REPLY_CAP))
        )
        (ite (or
            (is-Just (ms_unhandled_ppcall ms))
            (is-Just (ms_unhandled_reply ms))
        )
            (and
                true
                (is-SeL4_Cap_Reply reply_cap)
                (select (ks_reply_obj_has_cap ks) reply_cap)
            )
            (is-SeL4_Cap_Null reply_cap))
    ))

    (define-fun relation_recv_oracle (
        (mso NextRecv)
        (kso (Maybe KernelOracle))) Bool

        (ite (and (is-NR_Unknown mso) (is-Nothing kso))
            true
        (ite (and (is-NR_Notification mso) (is-Just kso))
            (let (
                (raised_flags (flags mso))
                (krnl_badge (snd (the kso)))
                (krnl_msginfo (fst (fst (the kso))))
                (new_reply_cap (snd (fst (the kso))))
            )
                ; ASSUMPTION: num_bits(krnl_badge)=64 < 2^64 (obviously true)
                ;
                ; We prove: for all bit in the kernel badge, it is 1 iff there
                ; is a corresponding flag and the flag is raised
                (and
                    (forall ((idx (_ BitVec 64)))
                        (=
                            (= ((_ extract 0 0) (bvshl krnl_badge idx)) (_ bv1 1))
                            (and
                                (is-Just (word2ch idx))
                                (select raised_flags (the (word2ch idx)))
                            )
                        )
                    )
                    (is-SeL4_Cap_Null new_reply_cap)
                )
            )
        (ite (and (is-NR_PPCall mso) (is-Just kso))
            (let
                (
                    (ch (fst (ppcall mso)))
                    (ms_msginfo (snd (ppcall mso)))
                    (ks_msginfo (fst (fst (the kso))))
                    (new_reply_cap (snd (fst (the kso))))
                    (ks_badge (snd (the kso)))
                    (two63 (bvshl (_ bv1 64) (_ bv63 64)))
                )
                (and
                    (relation_msg_info ms_msginfo ks_msginfo)
                    (= ks_badge (bvadd two63 (ch2word ch)))
                    (is-SeL4_Cap_Reply new_reply_cap)
                )
            )
        ; else
            false
        )))
    )

    (define-fun relation_bound_notification ((ms MicrokitState) (ks KernelState)) Bool
        (is-Just (ks_bound_notification ks))
    )

    (define-fun relation ((ms MicrokitState) (ks KernelState)) Bool
        (and
            (relation_cap_map (mi ms) (ms_running_pd ms) ks)
            (relation_mmrs_mem (mi ms) ks)
            (relation_reply_cap ms ks)
            (relation_recv_oracle (ms_recv_oracle ms) (ks_recv_oracle ks))
            (relation_bound_notification ms ks)
        )
    )

;
; Transition pre and post conditions
;


    (define-fun seL4_Signal/pre/specific ((cap SeL4_CPtr) (ks KernelState)) Bool
        (is-SeL4_Cap_Notification (select (ks_thread_cnode ks) cap))
    )
    (define-fun seL4_Signal/post/specific ((cap SeL4_CPtr) (ks KernelState) (ks/next KernelState)) Bool (= ks ks/next))

    (define-fun microkit_notify/pre/specific ((ch Ch) (ms MicrokitState)) Bool
        (exists ((comm Comm)) (and (select (mi_valid_comms (mi ms)) comm)
                                   (= (fst comm) (Prod (ms_running_pd ms) ch))))
    )
    (define-fun microkit_notify/post/specific ((ch Ch) (ms MicrokitState) (ms/next MicrokitState)) Bool (= ms ms/next))

    ; This might seem a bit silly, but here's the idea:
    ;
    ; We have an abstract state. Each function updates the concrete state
    ; (kernel) and the abstract state (microkit). The abstract state is updated
    ; by "ghost code" in the body of the function. We then have an invariant
    ; (relation) which must hold between the concrete and abstract state, and pre
    ; and post condition which can depend on both the concrete and abstract
    ; state.
    ;
    ; The haskell spec describes the ghost code and the post condition for the
    ; abstract state in one go (it's the same thing). But it doesn't have to be
    ; (post condition might say more than what the ghost code does). Hence why we
    ; split them up.
    ;
    ; When verifying a function, we assuming the abstract-update (ie. run the
    ; ghost code), and then prove the post condition. In _this_ case, it just
    ; means assuming ms=ms/next and then proving ms=ms/next.
    (define-fun microkit_notify/abstract-update ((ch Ch) (ms MicrokitState) (ms/next MicrokitState)) Bool (= ms ms/next))

    (define-fun microkit_irq_ack/pre/specific ((ch Ch) (ms MicrokitState)) Bool
        (select (mi_valid_irqns (mi ms)) (Prod (ms_running_pd ms) ch))
    )

    (define-fun microkit_irq_ack/post/specific ((ch Ch) (ms MicrokitState) (ms/next MicrokitState)) Bool
        (= ms ms/next)
    )

    (define-fun microkit_irq_ack/abstract-update ((ch Ch) (ms MicrokitState) (ms/next MicrokitState)) Bool
        (= ms ms/next)
    )

    (define-fun seL4_IRQHandler_Ack/pre/specific ((cptr SeL4_CPtr) (ks KernelState)) Bool
        (is-SeL4_Cap_IRQHandler (select (ks_thread_cnode ks) cptr))
    )

    (define-fun seL4_IRQHandler_Ack/post/specific ((cptr SeL4_CPtr) (ks KernelState) (ks/next KernelState)) Bool
        (= ks/next ks)
    )


    ; ------------------------------

    (define-fun seL4_Recv/pre/specific (
        (cptr SeL4_CPtr)
        (badge_ptr Word64)
        (reply_cptr SeL4_CPtr)
        (ks KernelState)
    ) Bool (and
        (= (select (ks_thread_cnode ks) cptr) (select (ks_thread_cnode ks) INPUT_CAP))

        (select (ks_local_mem_writable ks) badge_ptr)

        ; EXTRA: check rights on the cap
        (match (select (ks_thread_cnode ks) cptr) (
            ((SeL4_Cap_Endpoint ?1 ?2 cap_rights) (cr_read cap_rights))
            (?? false)
        ))

        (match (select (ks_thread_cnode ks) reply_cptr) (
            ; as far as I can tell, the reply cap doesn't need to have any
            ; special rights (inspect what the receive call did, and what you
            ; need when invoking a reply cap). A Grant right on the reply cap
            ; would mean that you are allowed to send capabilities _back_ to
            ; the caller.
            ((SeL4_Cap_Reply ?? cap_rights) true)
            (SeL4_Cap_Null true)
            (?? false)
        ))

        (is-Just (ks_recv_oracle ks))
    ))

    (define-fun seL4_Recv/post/specific (
        (cap SeL4_CPtr)
        (badge_ptr Word64)
        (reply_cptr SeL4_CPtr)
        (ks KernelState)

        (ret SeL4_MessageInfo)
        (ks/next KernelState)
    ) Bool (and
        ; from the precondition, we know that the recv_oracle is Just xx
        ; so it's ok to call `the` on it
        (let (
            (rv (fst (fst (the (ks_recv_oracle ks)))))
            (new_reply_cap (snd (fst (the (ks_recv_oracle ks)))))
            (badge_val (snd (the (ks_recv_oracle ks))))
            (two63 (bvshl (_ bv1 64) (_ bv63 64)))
        )
        (let (
            (received_ppcall (bvuge badge_val two63))
        )

        (let (
            (ks_reply_obj_has_cap/
                (store
                    (ks_reply_obj_has_cap ks)
                    new_reply_cap
                    received_ppcall
                )
            )
            (ks_local_mem/ (store (ks_local_mem ks) badge_ptr badge_val))

            (ks_thread_cnode/ (store (ks_thread_cnode ks) reply_cptr new_reply_cap))
        )

        ; EXTRA: The haskell forgets to state that the oracle is consumed!
        (let ((ks/ ks))
        (let ((ks/ ((_ update-field ks_reply_obj_has_cap) ks/ ks_reply_obj_has_cap/)))
        (let ((ks/ ((_ update-field ks_local_mem) ks/ ks_local_mem/)))
        (let ((ks/ ((_ update-field ks_recv_oracle) ks/ (as Nothing (Maybe KernelOracle)))))
        (let ((ks/ ((_ update-field ks_thread_cnode) ks/ ks_thread_cnode/)))
        (and
            (= ks/next ks/)
            (= ret rv)
        )
        ))))))
    ))))

    (define-fun _microkit_recv/pre/specific (
        (cptr SeL4_CPtr)
        (badge_ptr Word64)
        (reply_cptr SeL4_CPtr)
        (ms MicrokitState)
    ) Bool (and
        ; EXTRA: we require that you call only on the input cap
        (= cptr INPUT_CAP)
        ; EXTRA: require that the reply cptr is the 4
        (= reply_cptr REPLY_CAP)
        ; EXTRA: need to have that badge_ptr is writable memory
        ;        we make it even stronger: it needs to be writable local memory
        (is_writable_mem badge_ptr (mi ms))

        (match (ms_recv_oracle ms) (
            ((NR_Notification notifications) (distinct notifications notifications_empty))
            ((NR_PPCall ??) true)
            (NR_Unknown false)
        ))

        (= (ms_unhandled_notified ms) notifications_empty)

        (is-Nothing (ms_unhandled_ppcall ms))
        (is-Nothing (ms_unhandled_reply ms))
    ))

    (declare-const arbitrary_ms MicrokitState)

    ; TODO: remove, this is superficial (guaranteed by the precondition)
    (define-fun _microkit_recv/abstract-update-assumptions (
        (cptr SeL4_CPtr)
        (badge_ptr Word64)
        (reply_cptr SeL4_CPtr)
        (ms MicrokitState)

        (ms/next MicrokitState)
    ) Bool
        (or (is-NR_Notification (ms_recv_oracle ms))
            (is-NR_PPCall (ms_recv_oracle ms)))
    )

    (define-fun _microkit_recv/abstract-update (
        (cptr SeL4_CPtr)
        (badge_ptr Word64)
        (reply_cptr SeL4_CPtr)
        (ms MicrokitState)

        (ms/next MicrokitState)
    ) Bool (and
        (= ms/next (match (ms_recv_oracle ms) (
            ((NR_Notification notifications)
                ((_ update-field ms_recv_oracle)
                    ((_ update-field ms_unhandled_notified) ms notifications)
                NR_Unknown)
            )
            ((NR_PPCall ppcall)
                ((_ update-field ms_recv_oracle)
                    ((_ update-field ms_unhandled_ppcall) ms (Just ppcall))
                NR_Unknown)
            )
            (? arbitrary_ms) ; any proofs that will rely on this will fail
                             ; regardless, we know we cannot reach this case
                             ; if we can prove abstract-update-assumptions
        )))
    ))


    (declare-const arbitrary_message_info1 MsgInfo)
    (declare-const arbitrary_message_info2 MsgInfo)

    (define-fun _microkit_recv/post/specific (
        (cptr SeL4_CPtr)
        (badge_ptr Word64)
        (reply_cptr SeL4_CPtr)
        (ms MicrokitState)

        (ret MsgInfo)
        (ms/next MicrokitState)
    ) Bool (and
        (_microkit_recv/abstract-update cptr badge_ptr reply_cptr ms ms/next)

        (match (ms_recv_oracle ms) (
            ((NR_Notification notifications) true) ; we got nothing to say about return value
            ((NR_PPCall ch_msginfo) (= ret (snd ch_msginfo)))
            (? false) ; oracle wasn't consumed initially
        ))
    ))

    ; ------------------------

    (define-fun _microkit_ReplyRecv/pre/specific (
        (cptr SeL4_CPtr)
        (reply_tag MsgInfo)
        (badge_ptr Word64)
        (reply_cptr SeL4_CPtr)
        (ms MicrokitState)
    ) Bool
        (and
            ; EXTRA
            (= cptr INPUT_CAP)
            ; EXTRA
            (= reply_cptr REPLY_CAP)
            ; EXTRA
            (is_writable_mem badge_ptr (mi ms))

            (match (ms_recv_oracle ms) (
                ((NR_Notification notifications) (distinct notifications notifications_empty))
                ((NR_PPCall ??) true)
                (NR_Unknown false)
            ))

            (wf_MsgInfo reply_tag)
            (= (ms_unhandled_notified ms) ((as const (Array Ch Bool)) false))

            (is-Nothing (ms_unhandled_ppcall ms))
            (is-Just (ms_unhandled_reply ms))
        )
    )

    (declare-const arbitrary_ms2 MicrokitState)

    (define-fun _microkit_ReplyRecv/abstract-update (
        (cptr SeL4_CPtr)
        (reply_tag MsgInfo)
        (badge_ptr Word64)
        (reply_cptr SeL4_CPtr)
        (ms MicrokitState)
    ) MicrokitState
        (match (ms_recv_oracle ms) (
            ((NR_Notification notifications)
                (let ((ms/ ms))
                (let ((ms/ ((_ update-field ms_recv_oracle) ms/ NR_Unknown)))
                (let ((ms/ ((_ update-field ms_unhandled_notified) ms/ notifications)))
                (let ((ms/ ((_ update-field ms_unhandled_reply) ms/ (as Nothing (Maybe MsgInfo)))))
                (let ((ms/ ((_ update-field ms_last_handled_reply) ms/ (ms_unhandled_reply ms))))
                ms/
                )))))
            )
            ((NR_PPCall ppcall)
                (let ((ms/ ms))
                (let ((ms/ ((_ update-field ms_recv_oracle) ms/ NR_Unknown)))
                (let ((ms/ ((_ update-field ms_unhandled_ppcall) ms/ (Just ppcall))))
                (let ((ms/ ((_ update-field ms_unhandled_reply) ms/ (as Nothing (Maybe MsgInfo)))))
                (let ((ms/ ((_ update-field ms_last_handled_reply) ms/ (ms_unhandled_reply ms))))
                ms/
                )))))
            )
            ; shouldn't happen, guaranteed by the _microkit_ReplyRecv/pre/specific
            (NR_Unknown arbitrary_ms2)
        ))
    )

    (define-fun _microkit_ReplyRecv/post/specific (
        (cptr SeL4_CPtr)
        (reply_tag MsgInfo)
        (badge_ptr Word64)
        (reply_cptr SeL4_CPtr)
        (ms MicrokitState)
        (ret MsgInfo)
        (ms/next MicrokitState)
    ) Bool
        (and
            (= ms/next (_microkit_ReplyRecv/abstract-update cptr reply_tag badge_ptr reply_cptr ms))

            (match (ms_recv_oracle ms) (
                ((NR_Notification notifications) true) ; don't know anything about return value
                ((NR_PPCall ppcall) (= ret (snd ppcall)))
                (NR_Unknown false) ; shouldn't happen - guaranteed by precondition
            ))
        )
    )

    (define-fun seL4_ReplyRecv/pre/specific (
        (cptr SeL4_CPtr)
        (reply_tag SeL4_MessageInfo)
        (badge_ptr Word64)
        (reply_cptr SeL4_CPtr)
        (ks KernelState)
    ) Bool
        (and
            (= (select (ks_thread_cnode ks) cptr) (select (ks_thread_cnode ks) INPUT_CAP))
            ; EXTRA
            (select (ks_local_mem_writable ks) badge_ptr)

            (match (select (ks_thread_cnode ks) cptr) (
                ((SeL4_Cap_Endpoint obj_ref badge cap_rights) (cr_read cap_rights))
                (?? false)
            ))

            (match (select (ks_thread_cnode ks) reply_cptr) (
                ((SeL4_Cap_Reply obj_ref cap_rights) true) ; no cap_rights on the reply cap needed
                (?? false)
            ))

            (is-Just (ks_recv_oracle ks))
        )
    )

    (define-fun seL4_ReplyRecv/post/specific (
        (cptr SeL4_CPtr)
        (reply_tag SeL4_MessageInfo)
        (badge_ptr Word64)
        (reply_cptr SeL4_CPtr)
        (ks KernelState)
        (ret SeL4_MessageInfo)
        (ks/next KernelState)
    ) Bool
        (let (
           (rv (fst (fst (the (ks_recv_oracle ks)))))
           (new_reply_cap (snd (fst (the (ks_recv_oracle ks)))))
           (badge_val (snd (the (ks_recv_oracle ks))))
           (two63 (bvshl (_ bv1 64) (_ bv63 64)))
        )

        (let (
            (received_ppcall (bvuge badge_val two63))
        )

        (let (
            (ks_reply_obj_has_cap/
                (store
                    (store
                        (ks_reply_obj_has_cap ks)
                        (select (ks_thread_cnode ks) reply_cptr)
                        false
                    )
                    new_reply_cap
                    received_ppcall
                )
            )
            (ks_local_mem/ (store (ks_local_mem ks) badge_ptr badge_val))

            (ks_thread_cnode/ (store (ks_thread_cnode ks) reply_cptr new_reply_cap))
        )

        (let ((ks/ ks))
        (let ((ks/ ((_ update-field ks_local_mem) ks/ ks_local_mem/)))
        (let ((ks/ ((_ update-field ks_reply_obj_has_cap) ks/ ks_reply_obj_has_cap/)))
        (let ((ks/ ((_ update-field ks_recv_oracle) ks/ (as Nothing (Maybe KernelOracle)))))
        (let ((ks/ ((_ update-field ks_thread_cnode) ks/ ks_thread_cnode/)))
        (and
            (= ks/next ks/)
            (= ret rv)
        )
        ))))))))
    )

    ; -----------------

    (define-fun microkit_ppcall/pre/specific ((ch Ch) (msginfo MsgInfo) (ms MicrokitState)) Bool
        (exists ((comm Comm))
            (let (
                (pd1 (fst (fst comm)))
                (ch1 (snd (fst comm)))
                (pd2 (fst (snd comm)))
                (ch2 (snd (snd comm)))
            ) ; in
                (and
                    (select (mi_valid_comms (mi ms)) comm)
                    (= pd1 (ms_running_pd ms))
                    (= ch1 ch)
                    (select (mi_provides_pp (mi ms)) pd2)
                    (bvult (the (select (mi_prio (mi ms)) pd1)) (the (select (mi_prio (mi ms)) pd2)))

                    ; safe guards
                    (is-Just (select (mi_prio (mi ms)) pd1))
                    (is-Just (select (mi_prio (mi ms)) pd2))
                )
            )
        )
    )

    (define-fun microkit_ppcall/post/specific (
        (ch Ch)
        (msginfo MsgInfo)
        (ms MicrokitState)
        (ret MsgInfo)
        (ms/next MicrokitState)
    ) Bool
        (= ms ms/next)
    )

    (define-fun microkit_ppcall/abstract-update (
        (ch Ch)
        (msginfo MsgInfo)
        (ms MicrokitState)
        (ms/next MicrokitState)
    ) Bool
        (= ms ms/next)
    )

    (define-fun seL4_Call/pre/specific (
        (cptr SeL4_CPtr)
        (msginfo SeL4_MessageInfo)
        (ks KernelState)
    ) Bool
        (match (select (ks_thread_cnode ks) cptr) (
            ((SeL4_Cap_Endpoint obj_ref badge cap_rights)
                (and (cr_write cap_rights)
                     (cr_grant_reply cap_rights)))
            (?1 false)
        ))
    )

    (define-fun seL4_Call/post/specific (
        (cptr SeL4_CPtr)
        (msginfo SeL4_MessageInfo)
        (ks KernelState)
        (ret SeL4_MessageInfo)
        (ks/next KernelState)
    ) Bool
        (= ks ks/next)
        ; we don't specify what the return value of the call is, because from
        ; the perspective of an individual PD, we don't know. We'll need to
        ; look at the trace in a global proof to be able to do that.
    )

(define-fun cast_msginfo ((msginfo SeL4_MessageInfo)) MsgInfo
    (MI (seL4_mi_length msginfo)
        (seL4_mi_label msginfo))
)

;
; Verification
;


; to prove (a && b) --> (c && d)
; you can (assert (not (=> a b (and c d)))) (and get unsat)
;
; or you can (more readable)
;
;    (assert a)
;    (assert b)
;    (assert (not (and c d)))
;
; proof !((a && b) --> (c && d)) = !(!(a && b) || (c && d))
;                                = (a && b) && !(c && d)

    ; check that we don't have an obvious contradiction

    (push)
        (declare-const ks KernelState)
        (declare-const ms MicrokitState)

        (echo "?? trivial check [consistency]")
        (assert (wf_MicrokitInvariants (mi ms)))
        (assert (relation ms ks))
        (check-sat)
    (pop)

    (declare-const ks KernelState)
    (declare-const ks/next KernelState)
    (declare-const ms MicrokitState)
    (declare-const ms/next MicrokitState)

    (push) ; verify microkit_notify

        (declare-const ch Ch)

        ; static inline void
        ; sel4cp_notify(sel4cp_channel ch)
        ; {
        ;     seL4_Signal(BASE_OUTPUT_NOTIFICATION_CAP + ch);
        ; }
        ;
        ; need to prove that the notify's precondition implies signal's precondition
        ; and the signal's post condition implies notify's post condition

        ; Note that we don't check for overflow since they are channels
        ; are _unsigned_ ints.

        (push)
            (assert (relation ms ks))
            (assert (microkit_notify/pre/specific ch ms))
            (assert (wf_MicrokitInvariants (mi ms)))

            (echo "?? notify pre condition [consistency]")
            (check-sat)

            (assert (not (seL4_Signal/pre/specific (bvadd BASE_OUTPUT_NOTIFICATION_CAP (ch2word ch)) ks)))
            (echo "!! notify pre condition")
            (check-sat)
        (pop)

        (push)

            (assert (relation ms ks))
            (assert (wf_MicrokitInvariants (mi ms)))
            (assert (seL4_Signal/post/specific (bvadd BASE_OUTPUT_NOTIFICATION_CAP (ch2word ch)) ks ks/next))
            (assert (microkit_notify/abstract-update ch ms ms/next))

            (echo "?? notify post condition [consistency]")
            (check-sat)

            (assert (not (and
                (microkit_notify/post/specific ch ms ms/next)
                (relation ms/next ks/next)
                (wf_MicrokitInvariants (mi ms/next))
            )))
            (echo "!! notify post condition")
            (check-sat)
        (pop)
    (pop)

    (push) ; verify irq_ack
        (declare-const ch Ch)
        (declare-const cptr SeL4_CPtr)
        (declare-const msginfo MsgInfo)

        (assert (relation ms ks))
        (assert (wf_MicrokitInvariants (mi ms)))
        (assert (microkit_irq_ack/pre/specific ch ms))

        (assert (= cptr (bvadd BASE_IRQ_CAP (ch2word ch))))

        (echo "?? irq_ack [consistency]")
        (check-sat)

        (push)
            (assert (not (seL4_IRQHandler_Ack/pre/specific cptr ks)))
            (echo "!! irq_ack precondition")
            (check-sat)
        (pop)

        (push)

            (assert (microkit_irq_ack/abstract-update ch ms ms/next))
            (assert (seL4_IRQHandler_Ack/post/specific cptr ks ks/next))

            (assert (not (and
                (microkit_irq_ack/post/specific ch ms ms/next)
                (relation ms/next ks/next)
                (wf_MicrokitInvariants (mi ms/next))
            )))

            (echo "!! irq_ack postcondition")
            (check-sat)
        (pop)
    (pop)

    (push) ; verify recv
        (declare-const cptr SeL4_CPtr)
        (declare-const badge_ptr Word64)
        (declare-const reply_cptr SeL4_CPtr)
        (declare-const ret MsgInfo)
        (declare-const seL4_recv_ret SeL4_MessageInfo)

        (push) ; prove pre condition is established
            (assert (relation ms ks))
            (assert (wf_MicrokitInvariants (mi ms)))
            (assert (_microkit_recv/pre/specific cptr badge_ptr reply_cptr ms))
            ; (echo "?? recv precondition [consistency]")
            ; (check-sat)

            (assert (not (seL4_Recv/pre/specific cptr badge_ptr reply_cptr ks)))
            (echo "!! recv pre condition")
            (check-sat)
        (pop)

        (push) ; prove post condition is established
            (assert (relation ms ks))
            (assert (wf_MicrokitInvariants (mi ms)))
            (assert (_microkit_recv/pre/specific cptr badge_ptr reply_cptr ms))
            (assert (seL4_Recv/post/specific cptr badge_ptr reply_cptr ks seL4_recv_ret ks/next))

            (push)
                (assert (not (_microkit_recv/abstract-update-assumptions cptr badge_ptr reply_cptr ms ms/next)))
                (echo "!! abstract update assumption are valid")
                (check-sat)
            (pop)

            (assert (_microkit_recv/abstract-update cptr badge_ptr reply_cptr ms ms/next))

            ; implicit casting
            (assert (= ret (cast_msginfo seL4_recv_ret)))

            ; (echo "?? recv post condition")
            ; (check-sat)

            (push)
                (echo "!! check error")
                (assert (not (or
                    (is-NR_Notification (ms_recv_oracle ms))
                    (is-NR_PPCall (ms_recv_oracle ms)))))
                (check-sat)
            (pop)

            (assert (not (and
                (_microkit_recv/post/specific cptr badge_ptr reply_cptr ms ret ms/next)
                (relation ms/next ks/next)
                (wf_MicrokitInvariants (mi ms/next))
            )))
            (echo "!! recv post condition")
            (check-sat)

        (pop)
    (pop)

    (push) ; verify ReplyRecv
        (declare-const cptr SeL4_CPtr)
        (declare-const seL4_reply_tag SeL4_MessageInfo)
        (declare-const reply_tag MsgInfo)
        (declare-const badge_ptr Word64)
        (declare-const reply_cptr SeL4_CPtr)

        (declare-const ret MsgInfo)
        (declare-const seL4_ret SeL4_MessageInfo)

        ; implicit casting
        (assert (= ret (cast_msginfo seL4_ret)))
        (assert (= reply_tag (cast_msginfo seL4_reply_tag)))

        (assert (relation ms ks))
        (assert (wf_MicrokitInvariants (mi ms)))
        (assert (_microkit_ReplyRecv/pre/specific cptr reply_tag badge_ptr reply_cptr ms))

        ; (echo "?? reply recv [consistency]")
        ; (check-sat)

        (push)
            (assert (not (seL4_ReplyRecv/pre/specific cptr seL4_reply_tag badge_ptr reply_cptr ks)))
            (echo "!! seL4_ReplyRecv precondition")
            (check-sat)
        (pop)

        (push)
            (assert (seL4_ReplyRecv/post/specific cptr seL4_reply_tag badge_ptr reply_cptr ks seL4_ret ks/next))
            (assert (= ms/next (_microkit_ReplyRecv/abstract-update cptr reply_tag badge_ptr reply_cptr ms)))

            (assert (not (and
                (relation ms/next ks/next)
                (wf_MicrokitInvariants (mi ms/next))
                (_microkit_ReplyRecv/post/specific cptr reply_tag badge_ptr reply_cptr ms ret ms/next)
            )))
            (echo "!! _microkit_ReplyRecv postcondition")
            (check-sat)
        (pop)
    (pop)

    (push) ; verify ppcall
        (declare-const ch Ch)
        (declare-const cptr SeL4_CPtr)
        (declare-const msginfo MsgInfo)
        (declare-const ret MsgInfo)
        (declare-const seL4_Call_ret SeL4_MessageInfo)
        (declare-const seL4_msginfo SeL4_MessageInfo)

        (assert (relation ms ks))
        (assert (wf_MicrokitInvariants (mi ms)))

        (assert (= ret (cast_msginfo seL4_Call_ret)))
        ; note that in the program, the cast happens the other way. However,
        ; we write it this way so that the middle fields are left
        ; unspecified, and will prevent any proof that depends on them from
        ; going through.
        (assert (= msginfo (cast_msginfo seL4_msginfo)))

        ; no need to check for overflow since they are unsigned int
        (assert (= cptr (bvadd BASE_ENDPOINT_CAP (ch2word ch))))

        (assert (microkit_ppcall/pre/specific ch msginfo ms))

        (echo "?? trivial [consistency]")
        (check-sat)

        (push)
            (assert (not (seL4_Call/pre/specific cptr seL4_msginfo ks)))
            (echo "!! seL4_Call precondition")
            (check-sat)
        (pop)

        (push)
            (assert (seL4_Call/post/specific cptr seL4_msginfo ks seL4_Call_ret ks/next))
            (assert (microkit_ppcall/abstract-update ch msginfo ms ms/next))

            (assert (not (and
                (relation ms/next ks/next)
                (wf_MicrokitInvariants (mi ms/next))
                (microkit_ppcall/post/specific ch msginfo ms ret ms/next)
            )))

            (echo "!! microkit_ppcall post condition")
            (check-sat)
        (pop)
    (pop)

    ; TODO: proof that if relation for ks[mem], then relation holds for ks[mem']

    (push)
        (declare-const new_mem Mem)

        (assert (relation ms ks))
        (assert (not (relation ms ((_ update-field ks_local_mem) ks new_mem))))
        (echo "!! Relation holds accross local memory writes")
        (check-sat)
    (pop)


;
; Tests
;
; (push)
;     (assert (forall ((i (_ BitVec 8))) (bvshl)  ))
; (pop)
