(** This file defines a Symbol instantiation that
 ** has a special case for [eq] and [not] and supports
 ** other symbols through a polymorphic function
 ** environment.
 **
 ** NOTE
 **  It is not generic because it builds on top of Ext.Types
 **)
Require Import Coq.PArith.BinPos.
Require Import Coq.Lists.List.
Require Import Coq.FSets.FMapPositive.
Require Import ExtLib.Core.RelDec.
Require Import ExtLib.Data.Positive.
Require Import ExtLib.Tactics.Consider.
Require Import MirrorCore.SymI.
Require Import MirrorCore.TypesI.

Set Implicit Arguments.
Set Strict Implicit.

Definition func : Type := positive.

Global Instance RelDec_eq_func : RelDec (@eq func) := _.

Global Instance RelDec_Correct_eq_func : RelDec_Correct RelDec_eq_func := _.

Section RSym.
  Variable typ : Type.
  Variable RType_typ : RType typ.

  Record function := F
  { ftype : typ
  ; fdenote : forall ts, typD ts ftype
  }.

  Definition functions := PositiveMap.t function.
  Variable fs : functions.

  Definition func_typeof_sym (i : func) : option typ :=
    match PositiveMap.find i fs with
      | None => None
      | Some ft => Some ft.(ftype)
    end.

  Definition funcD ts (f : func) : match func_typeof_sym f with
                                     | None => unit
                                     | Some t => typD ts t
                                   end :=
    match PositiveMap.find f fs as Z
          return
          match
            match Z with
              | Some ft => Some (ftype ft)
              | None => None
            end
          with
            | Some t => typD ts t
            | None => unit
          end
    with
      | Some ft => ft.(fdenote) ts
      | None => tt
    end.

  Global Instance RSym_func : RSym func :=
  { sym_eqb := fun l r => Some (l ?[ eq ] r)
  ; typeof_sym := func_typeof_sym
  ; symD := funcD
  }.

  Global Instance RSymOk_func : RSymOk RSym_func.
  Proof.
    constructor.
    unfold sym_eqb; simpl.
    intros; consider (a ?[ eq ] b); auto.
  Qed.

  Definition from_list {T} (ls : list T) : PositiveMap.t T :=
    (fix from_list ls : positive -> PositiveMap.t T :=
       match ls with
         | nil => fun _ => PositiveMap.empty _
         | l :: ls => fun p =>
                        PositiveMap.add p l (from_list ls (Pos.succ p))
       end) ls 1%positive.

End RSym.