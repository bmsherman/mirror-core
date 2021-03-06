Require Import Coq.Lists.List.
Require Import Coq.Relations.Relations.
Require Import ExtLib.Data.Set.ListSet.
Require Import ExtLib.Tactics.Consider.
Require Import ExtLib.Tactics.Injection.
Require Import MirrorCore.TypesI.
Require Import MirrorCore.ExprI.
Require Import MirrorCore.EnvI.
Require Import MirrorCore.SubstI.

Set Implicit Arguments.
Set Strict Implicit.

Section sealed.
  Variable expr : Type.
  Variable lsubst : Type.
  Context {Subst_lsubst : Subst lsubst expr}.
  Let uvar : Type := nat.

  Record seal_subst : Type := SealedSubst
  { allowed : uvar -> bool
  ; subst : lsubst
  }.

  Instance Injective_seal_subst a b c d
  : Injective ({| allowed := a ; subst := b |} =
               {| allowed := c ; subst := d |}) :=
  { result := a = c /\ b = d }.
  Proof.
    abstract (inversion 1; intuition).
  Defined.

  Instance Subst_seal_subst : Subst seal_subst expr :=
  { set := fun u e s =>
             match s with
               | {| allowed := allow ; subst := subst |} =>
                 if allow u then
                   match set u e subst with
                     | None => None
                     | Some s => Some {| allowed := allow ; subst := s |}
                   end
                 else
                   None
             end
  ; lookup := fun u s => lookup u s.(subst)
  ; empty := {| allowed := fun _ => true ; subst := @SubstI.empty _ _ _ |}
  }.

  Variable typ : Type.
  Variable RType_typ : RType typ.
  Context {Expr_expr : Expr _ expr}.
  Context {mentionsU : uvar -> expr -> bool}.
  Context {SubstOk_lsubst : @SubstOk _ _ _ _ Expr_expr Subst_lsubst}.

  Instance SubstOk : SubstOk Expr_expr Subst_seal_subst :=
  { substD := fun us vs s => substD us vs s.(subst)
  ; WellTyped_subst := fun tus tvs s => WellTyped_subst tus tvs s.(subst)
  }.
  Proof.
    { simpl; apply substD_empty. }
    { simpl; apply WellTyped_empty. }

    destruct s; simpl; eauto using substD_lookup, WellTyped_lookup, WellTyped_set, substD_set.
    destruct s; simpl; eauto using substD_lookup.
    { destruct s; destruct s'; simpl; eauto using substD_lookup, WellTyped_lookup, WellTyped_set, substD_set.
      intros. destruct (allowed0 uv); try congruence.
      consider (set uv e subst0); intros; inv_all; subst; try congruence;
      eauto using WellTyped_set. }
    { destruct s; destruct s'; simpl; intros.
      destruct (allowed0 uv); try congruence; inv_all; subst.
      consider (set uv e subst0); try congruence; intros; inv_all; subst;
      eauto using substD_set. }
  Defined.

  Instance NormalizedSubstOk (N : NormalizedSubstOk Subst_lsubst mentionsU)
  : NormalizedSubstOk Subst_seal_subst mentionsU.
  Proof.
    constructor.
    { destruct s; simpl. eapply lookup_normalized; eauto. }
  Qed.

  Definition seal : (uvar -> bool) -> lsubst -> seal_subst := SealedSubst.

  Definition exclude (ls : list uvar) : lsubst -> seal_subst :=
    seal (fun u => negb (List.anyb (EqNat.beq_nat u) ls)).

  Definition allow (ls : list uvar) : lsubst -> seal_subst :=
    seal (fun u => List.anyb (EqNat.beq_nat u) ls).

End sealed.
