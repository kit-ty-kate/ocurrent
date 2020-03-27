(* Public API; see Current_git.mli for details of these: *)

type t
val api : t -> Api.t
val pp : t Fmt.t
val compare : t -> t -> int

val repositories : t Current.t -> Api.Repo.t list Current.t

(* Private API *)

val v : iid:int -> account:string -> api:Api.t -> t
(** [v ~iid ~account ~api] is the configuration for GitHub app installation [iid].
    @param account The GitHub account which installed the app.
    @param api The configuration used to access GitHub for this installation. *)

val input_installation_repositories_webhook : unit -> unit
(** Call this when we get the "installation" event. *)
