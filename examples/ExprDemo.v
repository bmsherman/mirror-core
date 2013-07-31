Require Import List.
Require Import ExtLib.Data.HList.
Require Import MirrorCore.Ext.Types.
Require Import MirrorCore.Ext.Expr.

(** Demo **)
Section Demo.
  Definition types' : types.
  refine ({| Impl := nat ; Eqb := fun _ _ => None |} ::
          {| Impl := list nat ; Eqb := fun _ _ => None |} :: nil); auto.
  Defined.

  Definition all (T : Type) (P : T -> Prop) : Prop :=
    forall x, P x.

  Definition typD := typD types'.

  Let tvNat := tvType 0.

  Definition funcs' : functions types'.
  refine (F types' 0
             (tvArr tvNat (tvArr tvNat tvNat))
             plus ::
          F _ 1
             (tvArr (tvArr (tvVar 0) tvProp) tvProp) 
             (fun x : Type => @ex x) ::
          F _ 1
             (tvArr (tvArr (tvVar 0) tvProp) tvProp) 
             all ::
          F _ 1
             (tvArr (tvVar 0) (tvArr (tvVar 0) tvProp))
             (fun T : Type => @eq T) ::
          F types' 0 (tvType 0) 0 ::
          nil).
  Defined.

  Goal
    let e := @App (@Func 1 (tvType 0 :: nil))
                    ((@Abs tvNat (@App (@Func 3 (tvType 0 :: nil))
                                                ((Var 0) :: @Func 4 nil :: nil))) :: nil) in
    match @exprD _ funcs' nil nil e tvProp with
      | None => False
      | Some p => p
    end.
  Proof.
    simpl. exists 0. reflexivity.
  Qed.
End Demo.
