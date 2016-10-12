Require Import ExtLib.Core.RelDec.
Require Import ExtLib.Data.Map.FMapPositive.
Require Import ExtLib.Data.Vector.
Require Import MirrorCore.TypesI.
Require Import MirrorCore.SymI.
Require Import MirrorCore.Views.View.
Require Import MirrorCore.Lambda.ExprCore.
Require Import MirrorCore.Polymorphic.

Set Implicit Arguments.
Set Strict Implicit.

Section poly.
  Context {typ : Type} {sym : Type}.
  Context {RT : RType typ}
          {RS : RSym sym}.

  Variable mkVar : positive -> typ.

  Variable typ_unify : typ -> typ -> pmap typ -> option (pmap typ).

  Definition sym_unifier : Type :=
    sym -> sym -> pmap typ -> option (pmap typ).

  Definition type_sym_unifier : sym_unifier :=
    fun a b s =>
      match typeof_sym a
          , typeof_sym b
      with
      | Some ta , Some tb =>
        match typ_unify ta tb s with
        | Some s' => Some s'
        | None => None
        end
      | _ , _ => None
      end.

  Variable su : sym_unifier.

  (** NOTE: This function does not need to be complete
   ** TODO: We should really stop looking at the term as
   **       soon as we have instantiated everything
   **)
  Local Fixpoint get_types {T} (a b : expr typ sym) (s : pmap typ)
        (ok : pmap typ -> T) (bad : T) {struct a}
  : T :=
    match a , b with
    | App fa aa , App fb ab =>
      get_types fa fb s
                (fun s' => get_types aa ab s' ok bad)
                bad
    | Inj a , Inj b =>
      match su a b s with
      | Some s => ok s
      | None => bad
      end
    | Inj _ , App _ _
    | App _ _ , Inj _
    | Abs _ _ , App _ _
    | App _ _ , Abs _ _ => bad
    | _ , _ => ok s
    end.

  Local Fixpoint build_vector p (n : nat) : vector typ n :=
    match n with
    | 0 => Vnil _
    | S n => Vcons (mkVar p) (build_vector (Pos.succ p) n)
    end.

  Local Fixpoint get_vector {T} n p
  : forall (ok : vector typ n -> T) (bad : T) (m : pmap typ), T :=
    match n as n return (vector typ n -> T) -> T -> pmap typ -> T with
    | 0 => fun ok _ _ => ok (Vnil _)
    | S n => fun ok bad m =>
               match pmap_lookup p m with
               | None => bad
               | Some z => get_vector (Pos.succ p)
                                      (fun vs => ok (Vcons z vs)) bad m
               end
    end.

  Definition get_inst {n} (t : polymorphic typ n (expr typ sym))
             (w : expr typ sym)
  : option (vector typ n) :=
    let t' := inst t (build_vector 1 n) in
    get_types t' w (pmap_empty _)
              (get_vector 1 Some None)
              None.
End poly.