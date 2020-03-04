open Current.Syntax

module S = S

let pp_tag = Fmt.using (Astring.String.cuts ~sep:":") Fmt.(list ~sep:(unit ":@,") string)

module Make (Host : S.HOST) = struct
  module Image = Image

  module PC = Current_cache.Make(Pull)

  let docker_context = Host.docker_context

  let pull ?label ~schedule tag =
    let label = Option.value label ~default:tag in
    Current.component "pull %s" label |>
    let> () = Current.return () in
    PC.get ~schedule Pull.No_context { Pull.Key.docker_context; tag }

  module BC = Current_cache.Make(Build)

  let pp_sp_label = Fmt.(option (prefix sp string))

  let option_map f = function
    | None -> None
    | Some x -> Some (f x)

  let get_build_context = function
    | `No_context -> Current.return `No_context
    | `Git commit -> Current.map (fun x -> `Git x) commit

  let build ?schedule ?timeout ?(squash=false) ?label ?dockerfile ?pool ?(build_args=[]) ~pull src =
    Current.component "build%a" pp_sp_label label |>
    let> commit = get_build_context src
    and> dockerfile = Current.option_seq dockerfile in
    let dockerfile =
      match dockerfile with
      | None -> `File (Fpath.v "Dockerfile")
      | Some (`File _ as f) -> f
      | Some (`Contents c) -> `Contents (Dockerfile.string_of_t c)
    in
    BC.get ?schedule { Build.pull; pool; timeout }
      { Build.Key.commit; dockerfile; docker_context; squash; build_args }

  module RC = Current_cache.Make(Run)

  let run ?label ?pool ?(run_args=[]) image ~args  =
    Current.component "run%a" pp_sp_label label |>
    let> image = image in
    RC.get { Run.pool } { Run.Key.image; args; docker_context; run_args }

  module PrC = Current_cache.Make(Pread)

  let pread ?label ?pool ?(run_args=[]) image ~args  =
    Current.component "pread%a" pp_sp_label label |>
    let> image = image in
    PrC.get { Pread.pool } { Pread.Key.image; args; docker_context; run_args }

  module TC = Current_cache.Output(Tag)

  let tag ~tag image =
    Current.component "docker-tag@,%a" pp_tag tag |>
    let> image = image in
    TC.set Tag.No_context { Tag.Key.tag; docker_context } { Tag.Value.image }

  module Push_cache = Current_cache.Output(Push)

  let push ?auth ~tag image =
    Current.component "docker-push@,%a" pp_tag tag |>
    let> image = image in
    Push_cache.set auth { Push.Key.tag; docker_context } { Push.Value.image }

  module SC = Current_cache.Output(Service)

  let service ~name ~image () =
    Current.component "docker-service@,%s" name |>
    let> image = image in
    SC.set Service.No_context { Service.Key.name; docker_context } { Service.Value.image }
end

module Default = Make(struct
    let docker_context = Sys.getenv_opt "DOCKER_CONTEXT"
  end)

module MC = Current_cache.Output(Push_manifest)

let push_manifest ?auth ~tag manifests =
  Current.component "docker-push-manifest@,%a" pp_tag tag |>
  let> manifests = Current.list_seq manifests in
  MC.set auth tag { Push_manifest.Value.manifests }
