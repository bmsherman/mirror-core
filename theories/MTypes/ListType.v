Require Import MirrorCore.TypesI.
Require Import MirrorCore.Views.FuncView.
Require Import MirrorCore.Views.Ptrns.
Require Import MirrorCore.MTypes.ModularTypes.
Require Import ExtLib.Core.RelDec.
Require Import ExtLib.Data.PList.

Set Implicit Arguments.
Set Strict Implicit.

(* This universe is only here as list_typ otherwise is cast to nat->Prop *)
Universes T.

Inductive list_typ : nat -> Type@{T} :=
| tList : list_typ 1.

Definition list_typ_dec {n} (a : list_typ n) : forall b, {a = b} + {a <> b} :=
  match a as a in list_typ n
        return forall b : list_typ n, {a = b} + {a <> b}
  with
  | tList =>
    fun b =>
      match b as b in list_typ 1 return {tList = b} + {tList <> b} with
      | tList => left eq_refl
      end
  end.

Definition list_typD {n} (t : list_typ n) : type_for_arity n :=
  match t with
  | tList => list
  end.

Section FuncView_list_type.
  Context {typ : Type}.
  Context {FV : PartialView typ (list_typ 1 * typ)}.

  Definition tyList t := f_insert (tList, t).

  Definition ptrn_tyList {T : Type} (p : Ptrns.ptrn typ T)
  : ptrn (list_typ 1 * typ) T :=
    fun f U good bad => p (snd f) U good (fun x => bad f).

  Global Instance ptrn_tyList_ok {T : Type} {p : ptrn typ T} {Hok : ptrn_ok p}
  : ptrn_ok (ptrn_tyList p).
  Proof.
    red; intros.
    destruct x; simpl; [destruct (Hok t)].
    { left. destruct H; exists x. revert H. compute; intros.
      rewrite H. reflexivity. }
    { right; unfold Fails in *; intros; simpl;
      unfold ptrn_tyList; rewrite H; reflexivity. }
  Qed.

End FuncView_list_type.
<<<<<<< HEAD

Section RelDec_list_type.

  Global Instance RelDec_list_typ (x : nat) : RelDec (@eq (list_typ x)) := {
    rel_dec := fun a b => 
                 match x with
                 | 1 => true
                 | _ => false
                 end
  }.

  Definition list_typ_eq (x y : list_typ 1) : x = y :=
    match x, y with
    | tList, tList => eq_refl
    end.

  Global Instance RelDecOk_list_typ (x : nat) : RelDec_Correct (RelDec_list_typ x).
  Proof.
    split; intros.
    destruct x; simpl in *; [inversion y|].
    inversion x0; subst.
    unfold rel_dec. simpl.
    split; intros; [|reflexivity].
    apply list_typ_eq.
  Qed.
  
End RelDec_list_type.
=======
>>>>>>> db1914a4d8e74b2d9be721b5d33619e790b8a9a1
