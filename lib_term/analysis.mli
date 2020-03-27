(* Static analysis of a build pipeline. *)

module Make (Meta : sig type job_id end) : sig
  type 'a t

  val stats : _ t -> S.stats

  val pp : _ t Fmt.t
  val pp_dot : url:(Meta.job_id -> string option) -> _ t Fmt.t
end with type 'a t := 'a Node.Make(Meta).t
