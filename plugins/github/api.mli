(* Public API; see Current_github.mli for details of these: *)

module Status : sig
  type t
  type state = [`Error | `Failure | `Pending | `Success ]

  val v : ?description:string -> ?url:Uri.t -> state -> t
end

module Commit : sig
  type t
  val id : t -> Current_git.Commit_id.t
  val repo_id : t -> Repo_id.t
  val owner_name : t -> string
  val hash : t -> string
  val pp : t Fmt.t
  val compare : t -> t -> int
  val set_status : t Current.t -> string -> Status.t Current.t -> unit Current.t
  val uri : t -> Uri.t
end

module Ref : sig
  type t = [ `Ref of string | `PR of int * string ]
  val compare : t -> t -> int
  val pp : t Fmt.t
  val to_git : t -> (string * string option)
end

module Ref_map : Map.S with type key = Ref.t

type t
val of_oauth : string -> t
val exec_graphql : ?variables:(string * Yojson.Safe.t) list -> t -> string -> Yojson.Safe.t Lwt.t
val head_commit : t -> Repo_id.t -> Commit.t Current.t
val refs : t -> Repo_id.t -> Commit.t Ref_map.t Current.Primitive.t
val head_of : t -> Repo_id.t -> Ref.t -> Commit.t Current.t
val ci_refs : t -> Repo_id.t -> Commit.t list Current.t
val cmdliner : t Cmdliner.Term.t

module Repo : sig
  type nonrec t = t * Repo_id.t

  val id : t -> Repo_id.t
  val ci_refs : t Current.t -> Commit.t list Current.t
  val head_commit : t Current.t -> Commit.t Current.t
  val pp : t Fmt.t
  val compare : t -> t -> int
end

(* Private API *)

val read_file : string -> string
(** [read_file path] is the contents of the file at [path] (just a utility function; should be moved elsewhere). *)

type token = {
  token : (string, [`Msg of string]) result;
  (** A token to include in the "Authorization" header, or an error if we failed to get a token. *)

  expiry : float option;
  (** [token] is valid until this time.
      If [token] is an [Error] then this is the earliest time to try again.
      If [None], [token] does not expire. *)
}

val get_token : t -> (string, [`Msg of string]) result Lwt.t
(** [get_token t] returns the cached token for [t], or fetches a new one if it has expired. *)

val input_webhook : Yojson.Safe.t -> unit
(** Call this when we get a "pull_request", "push" or "create" webhook event. *)

val v : get_token:(unit -> token Lwt.t) -> string -> t
(** [v ~get_token account] is a configuration that uses [get_token] when it needs to get or refresh the API token.
    Note: [get_token] can return a failed token, in which case the expiry time says when to try again.
          If [get_token] instead raises an exception, this is turned into an error token with a 1 minute expiry.
    @param account This is a string used to label point counters in Prometheus. *)
