FROM ocaml/opam2:alpine-3.8-ocaml-4.06
WORKDIR /home/opam
ADD links links
ADD opam-repository opam-repository-snapshot
ADD run-chatserver.sh run-chatserver.sh
ADD run-two-factor.sh run-two-factor.sh
ADD run-example.py run-example.py
ADD examples examples
ADD config config
USER root
WORKDIR /root
RUN apk update && apk upgrade && \
	apk add coreutils && \
	apk add camlp4 m4 libressl-dev pkgconfig && \
  apk add python2 && \
  apk add python3

ADD build.sh run.sh dune-project driver.ml dune eval_links.ml server.ml /home/opam/links/
RUN chown opam:nogroup -R /home/opam/links

USER opam
WORKDIR /home/opam/links

RUN \
  opam repository set-url default /home/opam/opam-repository-snapshot && \
  opam update && \
  opam install -y dune
RUN	eval $(opam env) && \
	opam pin add links . -y && \
	make nc && \
	sudo ln -s /home/opam/links/linx /usr/local/bin/
RUN eval $(opam env) && \
    ./build.sh
EXPOSE 8080


USER root
WORKDIR /root
RUN apk update && apk add --update py-pip && \
    apk add py3-zmq
   
USER opam
WORKDIR /home/opam/links

RUN pip3 install --upgrade pip && \
    python3 -m pip install --upgrade setuptools
   
RUN pip3 install jupyter && \
    pip3 install linkskernel
#    python -m links-kernel.install

USER opam


CMD [ "bash" ]
