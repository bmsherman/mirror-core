Require Import MirrorCore.ExprI.
Require Import MirrorCore.SymI.
Require Import MirrorCore.Lambda.TypesI2.
Require Import MirrorCore.Lambda.ExprCore.
Require Import MirrorCore.Lambda.ExprDFacts.
Require MirrorCore.Lambda.ExprDsimul.

Set Implicit Arguments.
Set Strict Implicit.

Export ExprDsimul.ExprDenote.

Module ExprFacts := ExprDFacts.Make ExprDsimul.ExprDenote.

Section Expr.
  Context {func : Type}.
  Context {RT : RType}
          {T2 : Typ2 _ PreFun.Fun}
          {RS : RSym typD func}.

  Instance Expr_expr : @Expr typ typD (@expr typ func) :=
  { exprD' := fun tus tvs e t => @exprD' _ _ _ _ nil tus tvs t e
  ; wf_Expr_acc := @wf_expr_acc typ func
  }.

  Context {RTOk : RTypeOk RT}
          {T2Ok : Typ2Ok T2}
          {RSOk : RSymOk RS}.

  Instance ExprOk_expr (ts : list Type) : ExprOk Expr_expr.
  Proof.
    constructor.
    { simpl. intros.
      eapply ExprFacts.exprD'_weaken; eauto. }
  Qed.

End Expr.