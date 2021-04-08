FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends jq curl vim ca-certificates bc \
    && rm -rf /var/lib/apt/lists/*

ENTRYPOINT ["bash", "-c"]
