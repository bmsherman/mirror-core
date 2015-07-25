Require Import ExtLib.Data.Fun.
Require Import ExtLib.Tactics.
Require Import MirrorCore.ExprI.
Require Import MirrorCore.AbsAppI.
Require Import MirrorCore.Lambda.ExprCore.
Require Import MirrorCore.Lambda.ExprD.
Require Import MirrorCore.Lambda.ExprDFacts.

Set Implicit Arguments.
Set Strict Implicit.

Section some_lemmas.
  Variable typ : Type.
  Variable sym : Type.
  Variable RType_typ : RType typ.
  Variable RTypeOk : RTypeOk.
  Variable Typ2_arr : Typ2 _ Fun.
  Variable Typ2Ok_arr : Typ2Ok Typ2_arr.
  Variable RSym_sym : RSym sym.
  Variable RSymOk_sym : RSymOk RSym_sym.

  Lemma exprD_typeof_not_None
  : forall tus tvs (e : expr typ sym) (t : typ) val,
      exprD' tus tvs t e = Some val ->
      typeof_expr tus tvs e <> None.
  Proof.
    intros.
    generalize (exprD'_typeof_expr _ (or_introl H)).
    congruence.
  Qed.

  Lemma exprD_typeof_Some
  : forall tus tvs e t val,
      exprD' tus tvs t e = Some val ->
      typeof_expr tus tvs e = Some t.
  Proof.
    intros.
    generalize (exprD'_typeof_expr _ (or_introl H)).
    congruence.
  Qed.

  Lemma exprD_typeof_eq
  : forall tus tvs e t t' val,
      exprD' tus tvs t e = Some val ->
      typeof_expr tus tvs e = Some t' ->
      t = t'.
  Proof.
    intros.
    generalize (exprD'_typeof_expr _ (or_introl H)).
    congruence.
  Qed.

  Global Instance Injective_typ2 {F : Type -> Type -> Type}
         {Typ2_F : Typ2 RType_typ F} {Typ2Ok_F : Typ2Ok Typ2_F} a b c d :
    Injective (typ2 a b = typ2 c d) :=
  { result := a = c /\ b = d }.
  abstract (
      eapply typ2_inj; eauto ).
  Defined.

  Global Instance Injective_typ1 {F : Type -> Type}
         {Typ1_F : Typ1 RType_typ F} {Typ2Ok_F : Typ1Ok Typ1_F} a b
  : Injective (typ1 a = typ1 b) :=
  { result := a = b }.
  abstract (
      eapply typ1_inj; eauto ).
  Defined.

  Lemma exprD'_AppI tus tvs (t : typ) (e1 e2 : expr typ sym)
        (P : option (exprT tus tvs (typD t)) -> Prop)
        (H : exists u v1 v2, exprD' tus tvs (typ2 u t) e1 = Some v1 /\
                             exprD' tus tvs u e2 = Some v2 /\
                             P (Some (exprT_App v1 v2))) :
    
    P (exprD' tus tvs t (App e1 e2)).
  Proof.
    autorewrite with exprD_rw; simpl.
    destruct H as [u [v1 [v2 [H1 [H2 HP]]]]].
    pose proof (exprD_typeof_Some _ _ H1).
    pose proof (exprD_typeof_Some _ _ H2).
    repeat (forward; inv_all; subst).
  Qed.
  
  Lemma exprD'_InjI tus tvs (t : typ) (f : sym)
        (P : option (exprT tus tvs (typD t)) -> Prop) 
        (H : exists v, symAs f t = Some v /\ P (Some (fun _ _ => v))) :
    P (exprD' tus tvs t (Inj f)).
  Proof.
    autorewrite with exprD_rw; simpl.
    destruct (symAs f t); simpl; destruct H as [v [H1 H2]]; try intuition congruence.
    inv_all; subst. apply H2.
  Qed.

  Require Import MirrorCore.ExprI.

  Global Instance Injective_exprD'_App tus tvs (e1 e2 : expr typ sym) (t : typ) 
         (v : exprT tus tvs (typD t)):
    Injective (ExprDsimul.ExprDenote.exprD' tus tvs t (App e1 e2) = Some v) := {
      result := exists u v1 v2, ExprDsimul.ExprDenote.exprD' tus tvs (typ2 u t) e1 = Some v1 /\
                                ExprDsimul.ExprDenote.exprD' tus tvs u e2 = Some v2 /\
                                v = exprT_App v1 v2;
      injection := fun H => _
    }.
  Proof.
    autorewrite with exprD_rw in H.
    simpl in H. forward; inv_all; subst.
    do 3 eexists; repeat split; eassumption.
  Defined.

  Global Instance Injective_exprD'_Inj tus tvs (f : sym) (t : typ) (v : exprT tus tvs (typD t)):
    Injective (ExprDsimul.ExprDenote.exprD' tus tvs t (Inj f) = Some v) := {
      result := exists v', symAs f t = Some v' /\ v = fun _ _ => v';
      injection := fun H => _
    }.
  Proof.
    autorewrite with exprD_rw in H.
    simpl in H. forward; inv_all; subst.
    eexists; repeat split.
  Defined.

End some_lemmas.

Ltac red_exprD :=
  autorewrite with exprD_rw; simpl. (** TODO: this should be restricted **)

Ltac forward_exprD :=
  repeat match goal with
           | H : _ = _ , H' : _ = _ |- _ =>
             let x := constr:(@exprD_typeof_eq _ _ _ _ _ _ _ _ _ _ _ _ _ _ H H') in
             match type of x with
               | ?X = ?X => fail 1
               | _ => specialize x ; intro ; try inv_all ; try subst
             end
           | H : exprD' _ _ ?T ?X = _ , H' : exprD' _ _ ?T' ?X = _ |- _ =>
             match T with
               | T' => fail 1
               | _ =>
                 generalize (@exprD'_deterministic _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ H H');
                   let X := fresh in intro X; red in X;
                   try inv_all; try subst
             end
         end.

Ltac arrow_case t :=
  let H := fresh in
  destruct (@typ2_match_case _ _ _ _ _ t) as [ [ ? [ ? [ ? H ] ] ] | H ];
    ( try rewrite H in * ).

Ltac arrow_case_any :=
  match goal with
    | H : appcontext [ @typ2_match _ _ _ _ _ ?X ] |- _ =>
      arrow_case X
  end.

Section lemmas.
  Variable typ : Type.
  Variable RType_typ : RType typ.
  Variable RTypeOk : RTypeOk.

  Theorem Relim_const
  : forall T a b (pf : Rty a b),
      Relim (fun _ => T) pf = fun x => x.
  Proof.
    clear. destruct pf. reflexivity.
  Qed.

  Lemma type_cast_sym_Some
  : forall a b pf,
      type_cast a b = Some pf ->
      type_cast b a = Some (Rsym pf).
  Proof.
    intros. destruct pf.
    rewrite type_cast_refl; eauto.
  Qed.

  Lemma type_cast_sym_None
  : forall a b,
      type_cast a b = None ->
      type_cast b a = None.
  Proof.
    intros.
    destruct (type_cast b a); auto.
    destruct r.
    rewrite type_cast_refl in H; eauto.
  Qed.
End lemmas.