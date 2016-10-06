Require Import Coq.Lists.List.
Require Import ExtLib.Data.HList.
Require Import ExtLib.Structures.Functor.
Require Import MirrorCore.MTypes.ModularTypesT.
Require MirrorCore.Reify.ReifyClass.


Set Implicit Arguments.
Set Strict Implicit.

Module Polymorphic.
  Declare Module TY : RType.
  Import TY.

  Section with_symbols.
    Variable tsym : kind -> Type.

    Fixpoint polymorphic (n : list kind) T : Type :=
      match n with
      | nil => T
      | n :: ns => type tsym n -> polymorphic ns T
      end.

    Section polymorphicD.
      Context {T : Type} (TD : T -> Prop).

      Fixpoint polymorphicD {n} : polymorphic n T -> Prop :=
        match n as n return polymorphic n T -> Prop with
        | nil => fun p => TD p
        | n :: ns => fun p => forall t, polymorphicD (p t)
        end.
    End polymorphicD.

    Fixpoint inst {T} (n : list kind)
    : polymorphic n T -> hlist (type tsym) n -> T :=
      match n as n return polymorphic n T -> hlist (type tsym) n -> T with
      | nil => fun p _ => p
      | n :: ns => fun p a => inst (p (hlist_hd a)) (hlist_tl a)
      end.

    Theorem inst_sound
    : forall {T} {n} (y: polymorphic n T) (P : T -> Prop) v,
        polymorphicD P y ->
        P (inst y v).
    Proof.
      induction n; simpl; eauto.
      intros; eapply IHn; eauto.
    Qed.

    Section make.
      Context {U : Type}.
      Fixpoint make_polymorphic n {struct n}
        : (hlist (type tsym) n -> U) -> polymorphic n U :=
        match n as n return (hlist (type tsym) n -> U) -> polymorphic n U with
        | nil => fun P => P Hnil
        | n' :: ns => fun P => fun v => (make_polymorphic (fun V => P (Hcons v V)))
        end.

      Theorem inst_make_polymorphic
      : forall n f v,
          @inst U n (make_polymorphic f) v = f v.
      Proof.
        induction v; simpl; try rewrite IHv; reflexivity.
      Qed.

      Theorem polymorphicD_make_polymorphic
        : forall (UD : U -> Prop) n (p : hlist _ n -> _),
          (forall v, UD (p v)) ->
          polymorphicD UD (make_polymorphic p).
      Proof.
        induction n; simpl; eauto.
      Qed.

    End make.

    Section fmap_polymorphic.
      Context {T U : Type}.
      Variable f : T -> U.
      Fixpoint fmap_polymorphic (n : list kind)
      : polymorphic n T -> polymorphic n U :=
        match n with
        | nil => f
        | n :: ns => fun x y => fmap_polymorphic ns (x y)
        end.
    End fmap_polymorphic.

    Instance Functor_polymorphic n : Functor (polymorphic n) :=
    { fmap := fun T U f => @fmap_polymorphic T U f n }.


    Section rpolymorphic.
      Context {k : Type}.
      Context {T : k -> Type}.
      Context {U : Type}.
      Context {r : Reify U}.

      Fixpoint rpolymorphic n : Command (polymorphic T n U) :=
        match n as n return Command (polymorphic T n U) with
        | nil => CCall (reify_scheme U)
        | n :: ns => Patterns.CPiMeta (rpolymorphic ns)
        end.

      Global Instance Reify_polymorphic n : Reify (polymorphic T n U) :=
        { reify_scheme := CCall (rpolymorphic n) }.
    End rpolymorphic.


    Arguments make_polymorphic {_ _ _} _.
    Arguments polymorphicD {_ _ _} _ {n} _.


Arguments inst {kind typ T n} p v : clear implicits, rename.



Arguments rpolymorphic _ _ _ _ _ : clear implicits.