Require Import MirrorCore.STac.Core.

Set Implicit Arguments.
Set Strict Implicit.

Section parameterized.
  Variable typ : Type.
  Variable expr : Type.
  Variable subst : Type.

  Definition TRY (b : stac typ expr subst) : stac typ expr subst :=
    fun tus tvs sub hs e =>
      match b tus tvs sub hs e with
        | Fail => More nil nil sub hs e
        | x => x
      end.

  Variable RType_typ : RType typ.
  Variable Expr_expr : Expr RType_typ expr.
  Variable ExprOk_expr : ExprOk Expr_expr.
  Variable Typ0_Prop : Typ0 _ Prop.
  Variable Subst_subst : Subst subst expr.
  Variable SubstOk_subst : @SubstOk _ _ _ _ Expr_expr Subst_subst.

  Theorem TRY_sound : forall b, stac_sound b -> stac_sound (TRY b).
  Proof.
    unfold stac_sound; intros.
    specialize (H tus tvs s hs g). unfold TRY.
    destruct (b tus tvs s hs g); auto.
    split; auto.
    apply More_sound.
  Qed.

End parameterized.

Arguments TRY {_ _ _} tac1 tac2 _ _ _ _ : rename.