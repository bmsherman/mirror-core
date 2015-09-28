Require Import Coq.omega.Omega.
Require Import ExtLib.Core.RelDec.
Require Import ExtLib.Structures.Traversable.
Require Import ExtLib.Data.HList.
Require Import ExtLib.Data.Eq.
Require Import ExtLib.Tactics.
Require Import MirrorCore.Util.ListMapT.
Require Import MirrorCore.Util.Compat.
Require Import MirrorCore.Util.HListBuild.
Require Import MirrorCore.ExprI.
Require Import MirrorCore.Util.Forwardy.
Require Import MirrorCore.Instantiate.

Set Implicit Arguments.
Set Strict Implicit.

Inductive hlist_Forall2 T (F G : T -> Type) (P : forall t, F t -> G t -> Prop)
: forall ls, hlist F ls -> hlist G ls -> Prop :=
| hlist_Forall2_nil : hlist_Forall2 P Hnil Hnil
| hlist_Forall2_cons : forall l ls x xs y ys,
                         @P l x y ->
                         hlist_Forall2 (ls := ls) P xs ys ->
                         hlist_Forall2 P (Hcons x xs) (Hcons y ys).

Section subst.
  Variable T : Type.
  Variable typ : Type.
  Variable expr : Type.
  Context {RType_type : RType typ}.
  Context {RTypeOk_type : RTypeOk}.
  Context {Expr_expr : Expr _ expr}.
  Context {ExprOk_expr : ExprOk _}.
(*
  Context {ExprUVar_expr : ExprUVar expr}.
  Context {ExprUVarOk_expr : ExprUVarOk ExprUVar_expr}.
*)

  Class Subst :=
  { subst_lookup : uvar -> T -> option expr
  ; subst_domain : T -> list uvar
  }.

  Class SubstOk (S : Subst) : Type :=
  { WellFormed_subst : T -> Prop
  ; substD : forall (tus tvs : tenv typ), T -> option (exprT tus tvs Prop)
  ; substD_lookup
    : forall s uv e,
        WellFormed_subst s ->
        subst_lookup uv s = Some e ->
        forall tus tvs sD,
          substD tus tvs s = Some sD ->
          exists t val get,
            nth_error_get_hlist_nth _ tus uv = Some (@existT _ _ t get) /\
            exprD' tus tvs e t = Some val /\
            forall us vs,
              sD us vs ->
              get us = val us vs
  ; WellFormed_domain : forall s ls,
      WellFormed_subst s ->
      subst_domain s = ls ->
      (forall n, In n ls <-> subst_lookup n s <> None)
  ; lookup_normalized : forall s e u,
      WellFormed_subst s ->
      subst_lookup u s = Some e ->
      forall u' e',
        subst_lookup u' s = Some e' ->
        mentionsU u' e = false
  }.

  Class SubstUpdate :=
  { subst_set : uvar -> expr -> T -> option T
  }.

  Class SubstUpdateOk (S : Subst) (SU : SubstUpdate) (SOk : SubstOk S) :=
  { substR : forall (tus tvs : tenv typ), T -> T -> Prop
  ; Reflexive_substR :> forall tus tvs, Reflexive (substR tus tvs)
  ; Transitive_substR :> forall tus tvs, Transitive (substR tus tvs)
  ; set_sound
      (** TODO(gmalecha): This seems to need to be rephrased as well **)
    : forall uv e s s',
        subst_set uv e s = Some s' ->
        WellFormed_subst s ->
        WellFormed_subst s' /\
        (subst_lookup uv s = None -> (* How important is this? *)
         forall tus tvs t val get sD,
           substD tus tvs s = Some sD ->
           nth_error_get_hlist_nth typD tus uv = Some (@existT _ _ t get) ->
           exprD' tus tvs e t = Some val ->
           exists sD',
             substD tus tvs s' = Some sD' /\
             substR tus tvs s s' /\
             forall us vs,
               sD' us vs <->
               (sD us vs /\ get us = val us vs))
  }.

(**
  Class SubstInstantiatable :=
  { subst_instantiate : (uvar -> option expr) -> T -> T }.

  (** the range of [f] does not include anything in the domain of s **)
  Definition disjoint_from (f : uvar -> option expr) (ls : list uvar) : Prop :=
    (forall u, In u ls -> f u = None) /\
    (forall u e, f u = Some e ->
                 forall u', In u' ls -> mentionsU u' e = false).

  Class SubstInstantiatableOk (S : Subst) (SO : SubstOk S) (SI : SubstInstantiatable) :=
  { instantiate_sound
    : forall f s s',
        subst_instantiate f s = s' ->
        WellFormed_subst s ->
        forall tus tvs P (EApp : ExprTApplicative P) sD,
          sem_preserves_if_ho P f ->
          substD tus tvs s = Some sD ->
          exists s'D,
            substD tus tvs s' = Some s'D /\
            P (fun us vs => sD us vs <-> s'D us vs)
  ; WellFormed_instantiate
    : forall f s s',
        subst_instantiate f s = s' ->
        WellFormed_subst s ->
        disjoint_from f (subst_domain s) ->
        WellFormed_subst s'
  }.
**)

  Class SubstOpen : Type :=
  { subst_drop : uvar -> T -> option T
  ; subst_weakenU : nat -> T -> T
(*  ; subst_split : uvar -> nat -> T -> option (T * T) *)
(*  ; strengthenV : nat -> nat -> T -> option T *)
  }.

  Fixpoint models (tus tvs : tenv typ) (tus' : tenv typ) (es : list (option expr))
  : option (hlist typD tus' -> exprT tus tvs Prop) :=
    match tus' as tus' , es
          return option (hlist typD tus' -> exprT tus tvs Prop)
    with
      | nil , nil => Some (fun _ _ _ => True)
      | tu' :: tus' , None :: es =>
        match models (tus ++ tu' :: nil) tvs tus' es with
          | None => None
          | Some x => Some (fun h us vs =>
                              x (hlist_tl h) (hlist_app us (Hcons (hlist_hd h) Hnil)) vs)
        end
      | tu' :: tus' , Some e :: es =>
        match models (tus ++ tu' :: nil) tvs tus' es with
          | None => None
          | Some x =>
            match exprD' (tus ++ tu' :: tus') tvs e tu' with
              | None => None
              | Some eD =>
                Some (fun h us vs =>
                           hlist_hd h = eD (hlist_app us h) vs
                        /\ x (hlist_tl h) (hlist_app us (Hcons (hlist_hd h) Hnil)) vs)
            end
        end
      | _ , _ => None
    end.

  Class SubstOpenOk (S : Subst) (SO : SubstOk S) (OS : SubstOpen) : Type :=
  { drop_sound
    : forall s s' u,
        subst_drop u s = Some s' ->
        WellFormed_subst s ->
        WellFormed_subst s' /\
        exists e,
          subst_lookup u s = Some e /\
          subst_lookup u s' = None /\
          (forall u', u' <> u -> subst_lookup u' s = subst_lookup u' s') /\
          forall tus tu tvs sD,
            u = length tus ->
            substD (tus ++ tu :: nil) tvs s = Some sD ->
            exists sD',
              substD tus tvs s' = Some sD' /\
              exists eD,
                exprD' tus tvs e tu = Some eD /\
                forall us vs,
                  sD' us vs <->
                  sD (hlist_app us (Hcons (eD us vs) Hnil)) vs
  ; substD_weakenU
    : forall n s s',
        subst_weakenU n s = s' ->
        forall tus tvs tus' sD,
          n = length tus' ->
          substD tus tvs s = Some sD ->
          exists sD',
            substD (tus ++ tus') tvs s' = Some sD' /\
            forall us us' vs,
              sD us vs <-> sD' (hlist_app us us') vs
  }.

  Context {Subst_subst : Subst}.
  Context {SubstOk_subst : SubstOk Subst_subst}.
  Context {SubstUpdate_subst : SubstUpdate}.
  Context {SubstUpdateOk_subst : SubstUpdateOk SubstUpdate_subst SubstOk_subst}.
  Context {SubstOpen_subst : SubstOpen}.
  Context {SubstOpenOk_subst : @SubstOpenOk _ _ _}.

  Lemma substD_conv
  : forall tus tus' tvs tvs' (pfu : tus' = tus) (pfv : tvs' = tvs) s,
      substD tus tvs s =
      match pfu in _ = u' return option (exprT u' _ Prop) with
        | eq_refl =>
          match pfv in _ = v' return option (exprT _ v' Prop) with
            | eq_refl => substD tus' tvs' s
          end
      end.
  Proof.
    clear. destruct pfu. destruct pfv. reflexivity.
  Qed.

  Fixpoint all_Some (ls : list (option expr)) : bool :=
    match ls with
      | nil => true
      | None :: _ => false
      | Some _ :: ls => all_Some ls
    end.

  Fixpoint all_defined (from : uvar) (len : nat) (s : T) : bool :=
    match len with
      | 0 => true
      | S len =>
        match subst_lookup from s with
          | None => false
          | Some _ => all_defined (S from) len s
        end
    end.

  (** This is the "obvious" extension of [drop] **)
  Fixpoint subst_pull (from : uvar) (len : nat) (s : T) : option T :=
    match len with
      | 0 => Some s
      | S len' => match subst_pull (S from) len' s with
                   | None => None
                   | Some s' => subst_drop from s'
                  end
    end.

  Fixpoint seq (start : nat) (len : nat) : list nat :=
    match len with
      | 0 => nil
      | S len => start :: seq (S start) len
    end.

  Lemma getInstantiation_syntactic
  : forall (s : T) tus tvs t (e : expr) sD,
      subst_lookup (length tus) s = Some e ->
      WellFormed_subst s ->
      substD (tus ++ t :: nil) tvs s = Some sD ->
      exists eD,
        exprD' tus tvs e t = Some eD /\
        forall us vs x,
          sD (hlist_app us (Hcons x Hnil)) vs ->
          x = eD us vs.
  Proof.
    intros.
    eapply substD_lookup in H1; eauto.
    forward_reason.
    eapply exprD'_strengthenU_single in H2; eauto.
    { forward_reason.
      eapply nth_error_get_hlist_nth_appR in H1; simpl in *; try omega.
      rewrite Minus.minus_diag in H1.
      forward_reason; inv_all; subst.
      eexists; split; eauto.
      intros. eapply H3 in H1; clear H3.
      rewrite H4 in H1. rewrite H5 in H1. subst.
      assumption. }
    { apply (@lookup_normalized _ _ _ _ _ H0 H _ _ H). }
  Qed.

  Lemma getInstantiation_syntactic_multi
  : forall (s : T) tus tvs ts (es : list expr) sD,
      mapT (fun u => subst_lookup u s) (seq (length tus) (length ts)) = Some es ->
      WellFormed_subst s ->
      substD (tus ++ ts) tvs s = Some sD ->
      exists esD : hlist (fun t => exprT tus tvs (typD t)) ts,
        @hlist_build_option typ (fun t => exprT tus tvs (typD t)) expr
                     (fun t e => exprD' tus tvs e t) ts es = Some esD /\
        forall us vs us',
          sD (hlist_app us (hlist_map (fun t (x : exprT tus tvs (typD t)) => x us vs) us')) vs ->
          hlist_Forall2 (fun t (x : exprT tus tvs (typD t))
                             (y : exprT tus tvs (typD t)) =>
                           x us vs = y us vs) us' esD.
  Proof.
  Abort.


  Theorem pull_sound
  : forall n s s' u,
      subst_pull u n s = Some s' ->
      WellFormed_subst s ->
      WellFormed_subst s' /\
      forall tus tus' tvs sD,
        u = length tus ->
        n = length tus' ->
        substD (tus ++ tus') tvs s = Some sD ->
        exists eus',
          mapT (fun u => subst_lookup u s) (seq u n) = Some eus' /\
          (forall u', u' < u \/ u' > u + n -> subst_lookup u' s = subst_lookup u' s') /\
          (forall u', u' < n -> subst_lookup (u + u') s' = None) /\
        exists sD',
          substD tus tvs s' = Some sD' /\
          exists us' : hlist (fun t => hlist typD tus -> hlist typD tvs -> typD t) tus',
            @hlist_build_option _ _ _ (fun t e => exprD' tus tvs e t) tus' eus' = Some us' /\
            forall us vs,
              let us' := hlist_map (fun t (x : hlist typD tus -> hlist typD tvs -> typD t) => x us vs) us' in
              sD' us vs <->
              sD (hlist_app us us') vs.
  Proof.
    Opaque mapT.
    induction n.
    { intros. simpl in *.
      inv_all. subst.
      split; auto.
      intros. subst.
      destruct tus'; try solve [ simpl in * ; congruence ].
      clear H1.
      exists nil. split; [ reflexivity | ].
      split; try reflexivity.
      split; [ inversion 1 | ].
      rewrite substD_conv with (pfu := eq_sym (app_nil_r_trans tus)) (pfv := eq_refl) in H2.
      autorewrite_with_eq_rw_in H2.
      forward.
      eexists; split; eauto.
      simpl. eexists; split; eauto.
      inv_all. subst.
      simpl. intros. rewrite hlist_app_nil_r.
      autorewrite with eq_rw. reflexivity. }
    { simpl. intros. forward.
      eapply IHn in H; clear IHn; auto.
      forward_reason.
      eapply drop_sound in H1; auto.
      forward_reason; split; auto.
      intros; subst.
      rewrite list_mapT_cons.
      destruct tus'; try solve [ simpl in *; congruence ].
      specialize (H2 (tus ++ t0 :: nil) tus' tvs).
      rewrite substD_conv with (pfv := eq_refl)
                               (pfu := app_ass_trans tus (t0 :: nil) tus') in H9.
      autorewrite_with_eq_rw_in H9.
      forwardy.
      assert (S (length tus) = length (tus ++ t0 :: nil)).
      { rewrite app_length. simpl. omega. }
      assert (n = length tus').
      { simpl in *; congruence. }
      specialize (H2 _ H10 H11 H7); clear H10 H11.
      forward_reason.
      rewrite H10 by omega. rewrite H3.
      change_rewrite H2.
      eexists; split; eauto.
      split; [ | split ].
      { destruct 1.
        { rewrite H10; eauto. rewrite H5 by omega. reflexivity. }
        { rewrite H10 by omega. rewrite H5 by omega. reflexivity. } }
      { intros. destruct u'.
        { replace (length tus + 0) with (length tus) by omega.
          assumption. }
        { replace (length tus + S u') with (S (length tus) + u') by omega.
          rewrite <- H5 by omega.
          eapply H11. omega. } }
      { specialize (H6 tus _ tvs _ eq_refl H12).
        forward_reason.
        eexists; split; eauto.
        simpl. rewrite H15.
        assert (exists us',
                  hlist_build_option
                    (fun t1 : typ =>
                       hlist typD tus -> hlist typD tvs -> typD t1)
                    (fun (t1 : typ) (e : expr) => exprD' tus tvs e t1) tus' x0 = Some us' /\
                  forall us vs val,
                    hlist_Forall2 (fun (t : typ)
                                       (x : hlist typD tus -> hlist typD tvs -> typD t)
                                       (y : hlist typD (tus ++ _ :: nil) -> hlist typD tvs -> typD t) =>
                                     x us vs = y (hlist_app us (Hcons val Hnil)) vs) us' x2).
        { clear H14. generalize dependent x2.
          assert (forall e, In e x0 ->
                            mentionsU (length tus) e = false).
          { intros.
            eapply mapT_In in H13; try eassumption.
            simpl in H13.
            forward_reason.
            eapply lookup_normalized.
            2: eassumption. eassumption.
            rewrite <- H10 in H3. eapply H3.
            left. omega. }
          generalize tus'. clear H7 H2.
          induction x0.
          { intros. destruct tus'0; simpl in *; try congruence.
            inv_all; subst. eexists; split; eauto.
            intros. constructor. }
          { intros. destruct tus'0; simpl in *; try congruence.
            forwardy. inv_all; subst.
            eapply IHx0 in H2; eauto.
            forward_reason.
            change_rewrite H2.
            assert (exists val, exprD' tus tvs a t1 = Some val /\
                                forall us vs v,
                                  val us vs = y1 (hlist_app us (Hcons v Hnil)) vs).
            { eapply exprD'_strengthenU_single in H7; eauto.
              forward_reason. eauto. }
            forward_reason. rewrite H9.
            eexists; split; eauto. intros.
            constructor; eauto. } }
        { forward_reason.
          change_rewrite H17.
          eexists; split; eauto.
          intros.
          inv_all; subst. clear H10 H11.
          rewrite H16; clear H16.
          rewrite H14; clear H14.
          simpl.
          rewrite hlist_app_assoc. simpl.
          autorewrite with eq_rw.
          match goal with
            | |- _ ?X _ <-> _ ?Y _ =>
              cutrewrite (X = Y); try reflexivity
          end.
          apply match_eq_match_eq.
          f_equal. f_equal.
          revert H13 H17.
          specialize (H18 us vs (x4 us vs)).
          clear - H18.
          generalize dependent x0.
          revert H18; revert x2; revert x5; revert tus'.
          refine (@hlist_Forall2_ind _ _ _ _ _ _ _).
          { simpl. reflexivity. }
          { simpl; intros.
            destruct x0; try congruence.
            specialize (H1 x0).
            repeat match goal with
                     | H : context [ ?X ] , H' : match ?Y with _ => _ end = _ |- _ =>
                       change Y with X in H' ; destruct X ; try congruence
                   end.
            forwardy. inv_all. subst.
            rewrite H1; auto. rewrite H. reflexivity. } } } }
  Qed.

  Lemma In_seq : forall a c b,
                   In a (seq b c) <-> (b <= a /\ a < b + c).
  Proof.
    clear.
    induction c; simpl; intros.
    { split. destruct 1. intros. omega. }
    { split; intros.
      { destruct H. subst. omega. eapply IHc in H. omega. }
      { consider (b ?[ eq ] a).
        { intros. subst; auto. }
        { right. eapply IHc. omega. } } }
  Qed.

  Lemma sem_preserves_if_substD
  : forall tus tvs s sD,
      WellFormed_subst s ->
      substD tus tvs s = Some sD ->
      sem_preserves_if_ho (fun P => forall us vs, sD us vs -> P us vs)
                          (fun u => subst_lookup u s).
  Proof.
    red. intros.
    eapply substD_lookup in H1; eauto.
    forward_reason.
    change_rewrite H2 in H1.
    inv_all; subst.
    eapply nth_error_get_hlist_nth_Some in H2.
    forward_reason. simpl in *.
    eexists; split; eauto.
  Qed.

(*
  Theorem pull_for_instantiate_sound
  : forall tus tus' tvs s s',
      subst_pull (length tus) (length tus') s = Some s' ->
      WellFormed_subst s ->
      WellFormed_subst s' /\
      forall sD,
        substD (tus ++ tus') tvs s = Some sD ->
        exists sD',
          substD tus tvs s' = Some sD' /\
          (forall e t eD,
             exprD' (tus ++ tus') tvs e t = Some eD ->
             exists eD',
               exprD' tus tvs (instantiate (fun u => subst_lookup u s) 0 e) t = Some eD' /\
               forall us vs us',
                 sD (hlist_app us us') vs ->
                 eD (hlist_app us us') vs = eD' us vs) /\
          forall us vs,
            exists us',
              sD' us vs <->
              sD (hlist_app us us') vs.
  Proof.
    intros.
    eapply pull_sound in H; eauto.
    forward_reason; split; auto.
    intros. specialize (H1 _ _ _ _ eq_refl eq_refl H2).
    forward_reason.
    eexists; split; eauto.
    split.
    { intros.
      eapply (@instantiate_sound typ expr _ _ _ _ _ _ _ _ nil) in H8; eauto.
      revert H8.
      instantiate (1 := sD).
      instantiate (1 := (fun u : uvar => subst_lookup u s)).
      simpl. intros.
      forward_reason.
      eapply exprD'_strengthenU_multi in H8; try eassumption.
      { forward_reason.
        eexists; split; eauto.
        intros.
        specialize (H10 us vs us').
        specialize (H9 (hlist_app us us') vs Hnil).
        simpl in H9.
        etransitivity; [ | eassumption ].
        auto. }
      { intros.
        match goal with
          | |- ?X = _ => consider X; auto
        end.
        intros. exfalso.
        generalize mentionsU_instantiate; intro XXX; red in XXX;
        rewrite XXX in H11; clear XXX.
        eapply mapT_success with (x := length tus + u) in H1.
        { forward_reason.
          destruct H11.
          { forward_reason; congruence. }
          { forward_reason.
            eapply lookup_normalized in H0.
            2: eapply H11.
            2: eapply H1.
            congruence. } }
        { eapply In_seq. omega. } }
      { eapply sem_preserves_if_substD; eauto. } }
    { intros. eauto. }
  Qed.
*)
End subst.

Arguments subst_pull {T SO} _ _ _ : rename.
