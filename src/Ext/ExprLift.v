Require Import List.
Require Import ExtLib.Data.ListNth.
Require Import ExtLib.Tactics.Consider.
Require Import ExtLib.Tactics.Injection.
Require Import ExtLib.Tactics.Cases.
Require Import MirrorCore.Ext.Types.
Require Import MirrorCore.Ext.ExprCore.
Require Import MirrorCore.Ext.ExprD.

Set Implicit Arguments.
Set Strict Implicit.

Section typed.
  Variable ts : types.

  Fixpoint lift' (s l : nat) (e : expr) : expr :=
    match e with
      | Var v =>
        if NPeano.ltb v s then e
        else Var (v + l)
      | Func _ _ => e
      | App e e' => App (lift' s l e) (lift' s l e')
      | Abs t e => Abs t (lift' (S s) l e)
      | UVar u => e
      | Equal t e1 e2 => Equal t (lift' s l e1) (lift' s l e2)
      | Not e => Not (lift' s l e)
    end.

  Definition lift (s l : nat) : expr -> expr :=
    match l with
      | 0 => fun x => x
      | _ => lift' s l
    end.

  Fixpoint lower' (s l : nat) (e : expr) : option expr :=
    match e with
      | Var v =>
        if NPeano.ltb v s then Some e
        else if NPeano.ltb (v - s) l then None
             else Some (Var (v - l))
      | Func _ _ => Some e
      | App e e' =>
        match lower' s l e , lower' s l e' with
          | Some e , Some e' => Some (App e e')
          | _ , _ => None
        end
      | Abs t e =>
        match lower' (S s) l e with
          | None => None
          | Some e => Some (Abs t e)
        end
      | UVar u => Some e
      | Equal t e1 e2 =>
        match lower' s l e1 , lower' s l e2 with
          | Some e1 , Some e2 =>
            Some (Equal t e1 e2)
          | _ , _ => None
        end
      | Not e =>
        match lower' s l e with
          | Some e => Some (Not e)
          | None => None
        end
    end.

  Fixpoint lower s l : expr -> option expr :=
    match l with
      | 0 => @Some _
      | _ => lower' s l
    end.

  Lemma lift'_0 : forall e s, lift' s 0 e = e.
  Proof.
    induction e; simpl; intros;
      repeat match goal with
               | [ H : _ |- _ ] => rewrite H
             end; auto.
    { consider (NPeano.ltb v s); auto. }
  Qed.

  Lemma lift_lift' : forall s l e, lift s l e = lift' s l e.
  Proof.
    destruct l; simpl; intros; auto using lift'_0.
  Qed.

  Fixpoint mentionsU (u : nat) (e : expr) {struct e} : bool :=
    match e with
      | Var _
      | Func _ _ => false
      | UVar u' => EqNat.beq_nat u u'
      | App f e => if mentionsU u f then true else mentionsU u e
      | Abs _ e => mentionsU u e
      | Equal _ e1 e2 => if mentionsU u e1 then true else mentionsU u e2
      | Not e => mentionsU u e
    end.


(*
  Theorem lift_welltyped : forall fs vs vs' us (e : expr) t,
    WellTyped_expr fs us (vs ++ vs') e t ->
    forall vs'' s l,
      s = length vs -> l = length vs'' ->
      WellTyped_expr fs us (vs ++ vs'' ++ vs') (lift s l e) t.
  Proof.
    intros. rewrite lift_lift'. subst. revert vs''.
    generalize dependent t. revert vs.
    induction e; simpl; intros; unfold WellTyped_expr in *; simpl in *; forward;
      repeat match goal with
               | [ H : _ |- _ ] => erewrite H by eauto
             end; auto.
    { consider (NPeano.ltb v (length vs)); intros; simpl.
      rewrite nth_error_app_L in * by auto. auto.
      rewrite nth_error_app_R in * by auto.
      rewrite nth_error_app_R by omega.
      rewrite nth_error_app_R by omega.
      rewrite <- H. f_equal. omega. }
    { consider (typeof_expr fs us (vs ++ vs') e); intros.
      { erewrite IHe by eassumption.
        rewrite map_map.
        revert H1. clear - H. revert t; revert t0.
        induction H; simpl; intros; auto.
        intros. consider (typeof_expr fs us (vs ++ vs') x); intros; try congruence.
        erewrite H by eauto.
        destruct (type_of_apply t0 t1); eauto.
        solve [ eapply fold_left_monadic_fail in H2; intuition ].
        solve [ eapply fold_left_monadic_fail in H2; intuition ]. }
      { solve [ eapply fold_left_monadic_fail in H1; intuition ]. } }
    { unfold WellTyped_expr in *; simpl in *; auto.
      consider (typeof_expr fs us (t :: vs ++ vs') e); intros; try congruence.
      inversion H0; clear H0; subst.
      eapply IHe with (vs := t :: vs) in H. simpl in H. rewrite H.
      inv_all; subst. reflexivity. }
  Qed.
*)

End typed.
