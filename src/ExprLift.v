Require Import List.
Require Import ExtLib.Data.ListNth.
Require Import ExprCore.
Require Import ExprT.

Set Implicit Arguments.
Set Strict Implicit.

Section typed.
  Variable ts : types.
  
  Fixpoint lift' (s l : nat) (e : expr ts) : expr ts :=
    match e with
      | Const _ _ => e
      | Var v =>
        if NPeano.ltb v s then e
        else Var (v + l)
      | Func _ _ => e
      | App e es => App (lift' s l e) (map (lift' s l) es)
      | Abs t e => Abs t (lift' (S s) l e)
      | UVar u => e
    end.

  Definition lift (s l : nat) : expr ts -> expr ts :=
    match l with
      | 0 => fun x => x
      | _ => lift' s l
    end.

  Require Import ExtLib.Tactics.Consider.

  Lemma lift'_0 : forall e s, lift' s 0 e = e.
  Proof.
    induction e; simpl; intros; auto.
    { consider (NPeano.ltb v s); auto. }
    { f_equal; auto.
      clear - H. induction H; simpl; auto. f_equal; auto. }
    { rewrite IHe. reflexivity. }
  Qed.

  Lemma lift_lift' : forall s l e, lift s l e = lift' s l e.
  Proof.
    destruct l; simpl; intros; auto using lift'_0.
  Qed.


  Theorem lift_welltyped : forall fs vs vs' us (e : expr ts) t, 
    WellTyped_expr fs us (vs ++ vs') e t ->
    forall vs'' s l,
      s = length vs -> l = length vs'' ->
      WellTyped_expr fs us (vs ++ vs'' ++ vs') (lift s l e) t.
  Proof.
    intros. rewrite lift_lift'. subst. revert vs''.
    generalize dependent t. revert vs.
    induction e; simpl; intros.
    { unfold WellTyped_expr in *; simpl in *; auto. }
    { unfold WellTyped_expr in *; simpl in *.
      consider (NPeano.ltb v (length vs)); intros; simpl.
      rewrite nth_error_app_L in * by auto. auto.
      rewrite nth_error_app_R in * by auto.
      rewrite nth_error_app_R by omega.
      rewrite nth_error_app_R by omega.
      rewrite <- H. f_equal. omega. }
    { unfold WellTyped_expr in *; simpl in *; auto. }
    { unfold WellTyped_expr in *; simpl in *; auto.
      consider (typeof_expr fs us (vs ++ vs') e); intros; try congruence.
      eapply IHe in H0. rewrite H0. rewrite map_map.
      revert H1. clear - H. revert t; revert t0.
      induction H; simpl; intros; auto.
      intros. consider (typeof_expr fs us (vs ++ vs') x); intros; try congruence.
      erewrite H by eauto. destruct t0; try congruence.
      destruct (typ_eqb t0_1 t1); try congruence. eauto. }
    { unfold WellTyped_expr in *; simpl in *; auto.
      consider (typeof_expr fs us (t :: vs ++ vs') e); intros; try congruence.
      inversion H0; clear H0; subst.
      eapply IHe with (vs := t :: vs) in H. simpl in H. rewrite H. reflexivity. }
    { unfold WellTyped_expr in *; simpl in *; auto. }
  Qed.

End typed.