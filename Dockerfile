FROM ocaml/opam2:4.08 AS build
RUN sudo apt-get update && sudo apt-get install graphviz m4 pkg-config libsqlite3-dev -y --no-install-recommends
RUN git pull origin master && git reset --hard f372039db86a970ef3e662adbfe0d4f5cd980701 && opam update
ADD --chown=opam *.opam /src/
WORKDIR /src
RUN opam install -y --deps-only -t .
ADD --chown=opam . .
RUN opam config exec -- dune build ./base-images/base_images.exe

FROM debian:10
RUN apt-get update && apt-get install curl dumb-init git graphviz libsqlite3-dev ca-certificates -y --no-install-recommends
RUN apt-get install gnupg2 -y --no-install-recommends
RUN curl -fsSL https://download.docker.com/linux/debian/gpg | apt-key add -
RUN echo 'deb [arch=amd64] https://download.docker.com/linux/debian buster stable' >> /etc/apt/sources.list
RUN apt-get update && apt-get install docker-ce -y --no-install-recommends
COPY --from=build /src/_build/default/base-images/base_images.exe /usr/local/bin/base-images
WORKDIR /var/lib/ocurrent
ENTRYPOINT ["dumb-init", "/usr/local/bin/base-images"]
