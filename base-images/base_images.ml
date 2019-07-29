open Current.Syntax

module Git = Current_git
module Docker = Current_docker.Default

let () = Logging.init ()

let weekly = Current_cache.Schedule.v ~valid_for:(Duration.of_day 7) ()

let password_path = "/run/secrets/ocurrent-hub"

let auth =
  if Sys.file_exists password_path then (
    let ch = open_in_bin "/run/secrets/ocurrent-hub" in
    let len = in_channel_length ch in
    let password = really_input_string ch len |> String.trim in
    close_in ch;
    Some ("ocurrent", password)
  ) else (
    Fmt.pr "Password file %S not found; images will not be pushed to hub@." password_path;
    None
  )

let opam_repository () =
  Git.clone ~schedule:weekly "git://github.com/ocaml/opam-repository"

let docker_file ~distro =
  let distro_name, tag = Dockerfile_distro.base_distro_tag distro in
  let+ base = Docker.pull ~schedule:weekly (Fmt.strf "%s:%s" distro_name tag) in
  let _, dockerfile = Dockerfile_opam.gen_opam2_distro ~from:(Docker.Image.hash base) distro in
  dockerfile

let distros ~arch =
  List.filter
    (Dockerfile_distro.distro_supported_on arch Ocaml_version.Releases.latest)
    (Dockerfile_distro.active_distros arch)

(* let distros ~arch:_ = ignore distros; [`Debian `V10] *)

let switches = ["4.08", "ocaml-base-compiler.4.08.0"]

let push image ~tag =
  match auth with
  | None -> Docker.tag image ~tag
  | Some auth -> Docker.push ~auth image ~tag

let pipeline () =
  let repo = opam_repository () in
  Current.all (
    distros ~arch:`X86_64 |> List.map @@ fun distro ->
    let opam_image = Docker.build ~label:"install opam" ~squash:true ~dockerfile:(docker_file ~distro) ~pull:false (`Git repo) in
    let tag = Dockerfile_distro.tag_of_distro distro in
    let opam_image_name = Fmt.strf "ocurrent/opam:%s-opam" tag in
    let push_opam = push opam_image ~tag:opam_image_name in
    Current.all (
      push_opam :: (
        switches |> List.map @@ fun (switch_name, switch) ->
        let dockerfile =
          let+ opam_image = opam_image in
          let open Dockerfile in
          from (Docker.Image.hash opam_image) @@
          crunch (
            run "opam-sandbox-disable" @@
            run "opam init -k git -a /home/opam/opam-repository --bare" @@
            run "opam switch create %s %s" switch_name switch
          )
        in
        let ocaml_image = Docker.build ~label:("install " ^ switch_name) ~squash:true ~dockerfile ~pull:false `No_context in
        let ocaml_image_name = Fmt.strf "ocurrent/opam:%s-ocaml-%s" tag switch_name in
        push ocaml_image ~tag:ocaml_image_name
      )
    )
  )

let main config mode =
  let engine = Current.Engine.create ~config pipeline in
  Logging.run begin
    Lwt.choose [
      Current.Engine.thread engine;
      Current_web.run ~mode engine;
    ]
  end

(* Command-line parsing *)

open Cmdliner

let cmd =
  let doc = "Build the ocaml/opam images for Docker Hub" in
  Term.(const main $ Current.Config.cmdliner $ Current_web.cmdliner),
  Term.info "docker_build_local" ~doc

let () = Term.(exit @@ eval cmd)
