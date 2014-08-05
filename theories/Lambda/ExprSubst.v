(** This file contains generic functions for manipulating,
 ** (i.e. substituting and finding) unification variables
 **)
Require Import ExtLib.Core.RelDec.
Require Import ExtLib.Data.Fun.
Require Import ExtLib.Data.Eq.
Require Import ExtLib.Data.Bool.
Require Import ExtLib.Data.Option.
Require Import ExtLib.Data.List.
Require Import ExtLib.Data.ListNth.
Require Import ExtLib.Data.HList.
Require Import ExtLib.Tactics.
Require Import MirrorCore.EnvI.
Require Import MirrorCore.SymI.
Require Import MirrorCore.ExprI.
Require Import MirrorCore.TypesI.
Require Import MirrorCore.InstantiateI.
Require Import MirrorCore.Util.Forwardy.
Require Import MirrorCore.Lambda.ExprCore.
Require Import MirrorCore.Lambda.ExprD.
Require Import MirrorCore.Lambda.ExprLift.

Set Implicit Arguments.
Set Strict Implicit.

Require Import FunctionalExtensionality.

Section mentionsU.
  Variable typ : Type.
  Variable func : Type.

  Lemma mentionsU_lift : forall u e a b,
    mentionsU u (lift (typ := typ) (func := func) a b e) = mentionsU u e.
  Proof.
    induction e; simpl; intros; intuition;
    Cases.rewrite_all_goal; intuition.
  Qed.

End mentionsU.

Section instantiate.
  Variable typ : Type.
  Variable func : Type.
  Variable lookup : uvar -> option (expr typ func).

  Fixpoint instantiate (under : nat) (e : expr typ func) : expr typ func :=
    match e with
      | Var _
      | Inj _ => e
      | App l r => App (instantiate under l) (instantiate under r)
      | Abs t e => Abs t (instantiate (S under) e)
      | UVar u =>
        match lookup u with
          | None => UVar u
          | Some e => lift 0 under e
        end
    end.

  Definition instantiates (u : uvar) : Prop :=
    lookup u <> None /\
    forall u' e, lookup u' = Some e ->
                 mentionsU u e = false.

  Lemma instantiate_instantiates
  : forall u,
      instantiates u ->
      forall e under,
        mentionsU u (instantiate under e) = false.
  Proof.
    induction e; simpl; intros; auto.
    { rewrite IHe1. auto. }
    { destruct H.
      consider (u ?[ eq ] u0).
      { intros; subst.
        specialize (H0 u0).
        destruct (lookup u0).
        { rewrite mentionsU_lift. auto. }
        { congruence. } }
      { intros.
        consider (lookup u0); intros.
        { rewrite mentionsU_lift. eauto. }
        { simpl. consider (EqNat.beq_nat u u0); try congruence. } } }
  Qed.

End instantiate.

Section instantiate_thm.
  Variable typ : Type.
  Variable func : Type.
  Variable RType_typ : RType typ.
  Variable Typ2_Fun : Typ2 _ Fun.
  Context {RSym_func : RSym func}.

  (** Reasoning principles **)
  Context {RTypeOk_typD : RTypeOk}.
  Context {Typ2Ok_Fun : Typ2Ok Typ2_Fun}.
  Context {RSymOk_func : RSymOk RSym_func}.

  Let Expr_expr := @Expr_expr _ _ RType_typ _ _.

  Lemma typeof_expr_instantiate
  : forall f tus tvs,
      (forall u e, f u = Some e ->
                   typeof_expr nil tus tvs e = nth_error tus u) ->
      forall e tvs',
        typeof_expr nil tus (tvs' ++ tvs) e =
        typeof_expr nil tus (tvs' ++ tvs) (instantiate f (length tvs') e).
  Proof.
    induction e; simpl; intros; auto.
    { rewrite (IHe1 tvs').
      rewrite (IHe2 tvs').
      reflexivity. }
    { specialize (IHe (t :: tvs')).
      simpl in IHe.
      rewrite IHe. reflexivity. }
    { specialize (H u).
      destruct (f u).
      { specialize (typeof_expr_lift nil tus e nil tvs' tvs).
        simpl.
        intro XXX; change_rewrite XXX; clear XXX.
        symmetry. eapply H; reflexivity. }
      { reflexivity. } }
  Qed.

  Lemma typeof_expr_instantiate'
  : forall f tus tvs,
      (forall u e t, f u = Some e ->
                     nth_error tus u = Some t ->
                     typeof_expr nil tus tvs e = Some t) ->
      forall e tvs' t,
        typeof_expr nil tus (tvs' ++ tvs) e = Some t ->
        typeof_expr nil tus (tvs' ++ tvs) (instantiate f (length tvs') e) = Some t.
  Proof.
    induction e; simpl; intros; auto.
    { forwardy.
      erewrite IHe1 by eassumption.
      erewrite IHe2 by eassumption.
      eassumption. }
    { specialize (IHe (t :: tvs')).
      simpl in IHe.
      forwardy.
      erewrite IHe by eassumption. eassumption. }
    { specialize (H u).
      destruct (f u).
      { specialize (typeof_expr_lift nil tus e nil tvs' tvs).
        simpl.
        intro XXX; change_rewrite XXX; clear XXX.
        eapply H; eauto. }
      { eapply H0. } }
  Qed.

  Theorem exprD'_instantiate
  : @exprD'_instantiate typ (expr typ func) RType_typ Expr_expr (@instantiate typ func).
  Proof.
    red. induction e; simpl; intros; eauto.
    { autorewrite with exprD_rw in *; eauto.
      simpl in *.
      forwardy.
      eapply typeof_expr_instantiate' with (f := f) in H0.
      change_rewrite H0.
      specialize (IHe1 tvs' (typ2 y t) _ _ H H1).
      specialize (IHe2 _ _ _ _ H H2).
      forward_reason.
      change_rewrite H5. change_rewrite H4.
      eexists; split; [ reflexivity | ].
      intros. inv_all; subst.
      unfold Open_App, OpenT, ResType.OpenT.
      autorewrite with eq_rw.
      rewrite H6 by assumption.
      rewrite H7 by assumption. reflexivity.
      clear - H RTypeOk_typD Typ2Ok_Fun RSymOk_func.
      red in H.
      intros.
      specialize (fun t get => H u e t get H0).
      simpl in *.
      consider (nth_error_get_hlist_nth (typD nil) tus u).
      { intros. destruct s.
        specialize (H2 _ _ H).
        forward_reason.
        eapply nth_error_get_hlist_nth_Some in H.
        simpl in H. forward_reason.
        rewrite x1 in H1. inv_all; subst.
        eapply exprD'_typeof_expr; eauto. }
      { intro. exfalso.
        eapply nth_error_get_hlist_nth_None in H. congruence. } }
    { autorewrite with exprD_rw in *.
      destruct (typ2_match_case nil t0) as [ [ ? [ ? [ ? ? ] ] ] | ? ].
      { rewrite H1 in *. clear H1.
        simpl in *.
        unfold Relim in *.
        autorewrite with eq_rw in *.
        forwardy.
        Cases.rewrite_all_goal.
        specialize (IHe (t :: tvs')_ _ _ H H3).
        forward_reason.
        simpl in *.
        Cases.rewrite_all_goal.
        eexists; split; eauto.
        intros.
        inv_all; subst.
        unfold OpenT, ResType.OpenT.
        autorewrite with eq_rw.
        eapply match_eq_match_eq.
        eapply match_eq_match_eq with (F := fun x => x).
        apply functional_extensionality.
        intro. eapply (H6 us vs (Hcons (Rcast_val y1 x3) vs')); auto. }
      { rewrite H1 in H0.
        exfalso. congruence. } }
    { red in H.
      specialize (H u).
      destruct (f u).
      { autorewrite with exprD_rw in *; simpl in *.
        forwardy.
        specialize (H _ _ _ eq_refl H0).
        forward_reason.
        generalize (exprD'_lift nil tus e nil tvs' tvs t).
        destruct y.
        simpl. change_rewrite H.
        intros; forwardy.
        eexists; split; [ eassumption | ].
        intros.
        inv_all; subst.
        erewrite H3 by eauto. eapply (H5 us Hnil vs' vs). }
      { clear H.
        eexists; split; [ eassumption | ].
        reflexivity. } }
  Qed.

  Theorem if_true_iff
  : forall T (a : bool) (b c d : T),
      (if a then b else c) = d <->
      ((a = true /\ b = d) /\ (a = false /\ c = d)).
  Proof.
  Admitted.

  Theorem instantiate_mentionsU
  : @instantiate_mentionsU typ (expr typ func) RType_typ Expr_expr (@instantiate typ func).
  Proof.
    clear.
    red. intros f n e u. revert n.
    induction e; simpl; intros.
    { split; intros. congruence.
      destruct H. destruct H; auto.
      forward_reason; auto. }
    { split; intros. congruence.
      destruct H. destruct H; auto.
      forward_reason; auto. }
    { specialize (IHe1 n). specialize (IHe2 n).
      simpl in *.
      transitivity (mentionsU u (instantiate f n e1) = true \/ mentionsU u (instantiate f n e2) = true).
      { destruct (mentionsU u (instantiate f n e1)); intuition. }
      { rewrite IHe1. rewrite IHe2.
        split.
        { destruct 1.
          { destruct H; forward_reason.
            { rewrite H0. left; auto. }
            { right. do 2 eexists; split; [ eassumption | ].
              rewrite H0. eauto. } }
          { destruct H; forward_reason.
            { rewrite H. rewrite H0.
              left. split; auto. destruct (mentionsU u e1); reflexivity. }
            { right. do 2 eexists; split; eauto.
              split; auto.
              destruct (mentionsU x e1); eauto. } } }
        { destruct 1; forward_reason.
          { rewrite H. destruct (mentionsU u e1).
            { left. left; auto. }
            { right; left; auto. } }
          { consider (mentionsU x e1).
            { left; right. do 2 eexists; split; eauto. }
            { intros. right; right; do 2 eexists; split; eauto. } } } } }
    { specialize (IHe (S n)). simpl in IHe. eapply IHe. }
    { split.
      { consider (EqNat.beq_nat u u0).
        { intros; subst.
          consider (f u0).
          + intros. right.
            rewrite mentionsU_lift in H0.
            do 2 eexists; split; eauto.
            split. consider (EqNat.beq_nat u0 u0); auto. auto.
          + intros. left; auto. }
        { intros. right.
          consider (f u0); intros.
          { do 2 eexists.
            split; eauto. rewrite mentionsU_lift in H1.
            split; auto.
            consider (EqNat.beq_nat u0 u0); auto. }
          { simpl in H1.
            exfalso.
            consider (EqNat.beq_nat u u0). apply H. } } }
      { intros. destruct H.
        { destruct H.
          consider (EqNat.beq_nat u u0).
          intros; subst.
          rewrite H. simpl.
          consider (EqNat.beq_nat u0 u0); auto. }
        { forward_reason.
          consider (EqNat.beq_nat x u0).
          intros; subst.
          rewrite H. rewrite mentionsU_lift. assumption. } } }
  Qed.

End instantiate_thm.
