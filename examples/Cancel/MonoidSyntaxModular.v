Require Import ExtLib.Data.Fun.
Require Import MirrorCore.ExprI.
Require Import MirrorCore.TypesI.
Require Import MirrorCore.SymI.
Require MirrorCore.syms.SymEnv.
Require MirrorCore.syms.SymSum.
Require Import MirrorCore.MTypes.ModularTypes.
Require Import MirrorCore.Lambda.ExprCore.
Require Import MirrorCore.Lambda.Expr.
Require Import MirrorCore.Simple.
Require Import MirrorCore.Reify.Reify.
Require Import MirrorCore.RTac.Interface.
Require Import McExamples.Cancel.Monoid.

Set Implicit Arguments.
Set Strict Implicit.

Module Syntax (M : Monoid).

  (** Define the reified language *)
  (********************************)

  (* The syntax of types *)
  Inductive typ' : nat -> Type :=
  | tyNat : typ' 0
  | tyProp : typ' 0
  | tyM : typ' 0.

  Definition typ'_dec {n} (a : typ' n) : forall b, {a = b} + {a <> b}.
  refine
    match a as a in typ' n return forall b : typ' n, {a = b} + {a <> b} with
    | tyNat => fun b =>
                 match b as b in typ' 0 return {tyNat = b} + {tyNat <> b} with
                 | tyNat => left eq_refl
                 | _ => right (fun pf => _)
                 end
    | tyProp => fun b =>
                 match b as b in typ' 0 return {tyProp = b} + {tyProp <> b} with
                 | tyProp => left eq_refl
                 | _ => right (fun pf => _)
                 end
    | tyM => fun b =>
                 match b as b in typ' 0 return {tyM = b} + {tyM <> b} with
                 | tyM => left eq_refl
                 | _ => right (fun pf => _ )
                 end
    end; try solve [ clear - pf ; inversion pf ].
  Defined.

  Definition typ'D {n} (t : typ' n) : type_for_arity n :=
    match t with
    | tyNat => nat
    | tyProp => Prop
    | tyM => M.M
    end.

  Instance TSym_typ' : TSym typ' :=
  { symbolD := @typ'D
  ; symbol_dec := @typ'_dec }.

  Definition typ := mtyp typ'.

  (* Instantiate the RType interface *)
  Instance RType_typ : RType typ := RType_mtyp typ' _.
  Instance RTypeOk_typ : RTypeOk := @RTypeOk_mtyp typ' _.

  (* Build instances for describing functions and Prop *)
  Instance Typ2_tyArr : Typ2 RType_typ Fun := Typ2_Fun.
  Instance Typ2Ok_tyArr : Typ2Ok Typ2_tyArr := Typ2Ok_Fun.

  Instance Typ0_tyProp : Typ0 RType_typ Prop := Typ0_sym tyProp.
  Instance Typ0Ok_tyProp : Typ0Ok Typ0_tyProp := Typ0Ok_sym tyProp.

  (* The syntax of terms *)
  Inductive func' :=
  | Eq : typ -> func' (* polymorphic equality *)
  | Ex : typ -> func' | All : typ -> func' (* polymorphic quantification *)
  | And | Or | Impl
  | mU | mP | mR.

  Definition func'_eq_dec : forall a b : func', {a = b} + {a <> b}.
  Proof.
    decide equality; eauto using mtyp_dec, typ'_dec with typeclass_instances.
  Defined.

  Arguments tyArr {_} _ _.
  Arguments tyBase0 {_} _.
  Arguments tyBase1 {_} _ _.
  Arguments tyBase2 {_} _ _ _.
  Arguments tyApp {_ _} _ _.
  Local Notation "! x" := (@tyBase0 _ x) (at level 0).

  (* The meaning of symbols *)
  Definition RSym_func' : RSym func'.
  refine (
    RSym_simple
      (fun f => Some
         match f with
         | mU => mkTypedVal !tyM M.U
         | mP => mkTypedVal (tyArr !tyM (tyArr !tyM !tyM)) M.P
         | mR => mkTypedVal (tyArr !tyM (tyArr !tyM !tyProp)) M.R
         | Eq t => mkTypedVal (tyArr t (tyArr t !tyProp)) (@eq _)
         | And => mkTypedVal (tyArr !tyProp (tyArr !tyProp !tyProp)) and
         | Or => mkTypedVal (tyArr !tyProp (tyArr !tyProp !tyProp)) or
         | Impl => mkTypedVal (tyArr !tyProp (tyArr !tyProp !tyProp)) Basics.impl
         | Ex t => mkTypedVal (tyArr (tyArr t !tyProp) !tyProp) (@ex _)
         | All t => mkTypedVal (tyArr (tyArr t !tyProp) !tyProp) _
         end)
      func'_eq_dec).
  refine (fun P : _ -> Prop => forall x : typD t, P x).
  Defined.

  Instance RSymOk_func' : RSymOk RSym_func' := _.

  Definition func : Type := sum func' SymEnv.func.

  Instance RSym_func fs : RSym func :=
    SymSum.RSym_sum RSym_func' (@SymEnv.RSym_func _ _ fs).

  Instance RSymOk_func fs : RSymOk (RSym_func fs).
  Proof.
    apply SymSum.RSymOk_sum; eauto with typeclass_instances.
  Qed.

  Definition known (f : func') : expr typ func := Inj (inl f).
  Definition other (f : SymEnv.func) : expr typ func := Inj (inr f).

  (** Reification **)
  (*****************)

  Local Notation "x @ y" := (@RApp x y) (only parsing, at level 30).
  Local Notation "'!!' x" := (@RExact _ x) (only parsing, at level 25).
  Local Notation "'?' n" := (@RGet n RIgnore) (only parsing, at level 25).
  Local Notation "'?!' n" := (@RGet n RConst) (only parsing, at level 25).
  Local Notation "'#'" := RIgnore (only parsing, at level 0).

  (* Declare patterns **)
  Reify Declare Patterns patterns_monoid_typ : typ.
  Reify Declare Patterns patterns_monoid : (expr typ func).

  (* Declare the syntax for the types *)
  Reify Declare Syntax reify_monoid_typ :=
    CPatterns patterns_monoid_typ.

  Reify Declare Typed Table table_terms : BinNums.positive => typ.

  (* Declare syntax **)
  Reify Declare Syntax reify_monoid :=
    CFix
      (CFirst (CPatterns patterns_monoid ::
               CApp (CRec 0) (CRec 0) (@ExprCore.App typ func) ::
               CAbs (CCall reify_monoid_typ) (CRec 0) (@ExprCore.Abs typ func) ::
               CVar (@ExprCore.Var typ func) ::
               CMap other (CTypedTable reify_monoid_typ table_terms) :: nil)).

  (* Pattern rules for reifying types *)
  Reify Pattern patterns_monoid_typ += (@RExact _ nat)  => !tyNat.
  Reify Pattern patterns_monoid_typ += (@RExact _ M.M) => !tyM.
  Reify Pattern patterns_monoid_typ += (@RExact _ Prop) => !tyProp.
  Reify Pattern patterns_monoid_typ += (@RImpl (@RGet 0 RIgnore) (@RGet 1 RIgnore)) => (fun (a b : function (CCall reify_monoid_typ)) => @tyArr typ' a b).

  (* Pattern rules for reifying terms *)
  Reify Pattern patterns_monoid += (@RExact _ M.P) => (known mP).
  Reify Pattern patterns_monoid += (@RExact _ M.U) => (known mU).
  Reify Pattern patterns_monoid += (@RExact _ M.R) => (known mR).
  Reify Pattern patterns_monoid += (RApp (@RExact _ (@eq)) (RGet 0 RIgnore)) =>
  (fun (t : function (CCall reify_monoid_typ)) => Inj (typ:=typ) (Eq t)).
  Reify Pattern patterns_monoid += (RPi (RGet 0 RIgnore) (RGet 1 RIgnore)) => (fun (t : function (CCall reify_monoid_typ)) (b : function (CCall reify_monoid)) => (App (known (All t)) (Abs t b))).
  Reify Pattern patterns_monoid += (@RImpl (@RGet 0 RIgnore) (@RGet 1 RIgnore)) => (fun (a b : function (CCall reify_monoid)) => App (App (known Impl) a) b).

  Global Instance Reify_typ : Reify typ :=
  { reify_scheme := CCall reify_monoid_typ }.

  Global Instance Reify_expr_typ_func : Reify (expr typ func) :=
  { reify_scheme := CCall reify_monoid }.

  Ltac run_tbl_rtac the_Expr the_tactic the_tactic_sound :=
    lazymatch goal with
    | |- ?trm =>
      let k tbl e :=
          let result :=
              constr:(@Interface.runRtac typ (expr typ func) nil nil e (the_tactic tbl)) in
          let resultV := eval vm_compute in result in
          match resultV with
          | Solved _ =>
            change (@env_propD _ _ _ Typ0_tyProp (the_Expr tbl) nil nil e) ;
              cut (result = resultV) ;
              [ set (pf := @Interface.rtac_Solved_closed_soundness
                             _ _ _ _ _ _ (the_tactic_sound tbl)
                             nil nil e) ;
                exact pf
              | vm_cast_no_check (@eq_refl _ resultV) ]
          end
      in
      reify_expr_bind reify_monoid k
                      [[ (fun x : @mk_dvar_map _ _ _ typD table_terms (@SymEnv.F typ _) => True) ]]
                      [[ trm ]]
  end.

  Definition the_Expr fs := (@Expr.Expr_expr typ func _ _ (RSym_func fs)).

End Syntax.