# Kubernetes Gelf Forwarder
[![](https://images.microbadger.com/badges/image/oba11/kubernetes-gelf-forwarder.svg)](https://microbadger.com/images/oba11/kubernetes-gelf-forwarder)

This repository contains the docker image forward kubernetes systemd components to gelf server.<br/>
You need to set `GELF_1_HOST` and `GELF_1_PORT` to forward kubernetes systemd components to the gelf server.

It also supports forwarding container prefix regex to gelf server.<br/>
You can as well forward container logs to different gelf servers (up to 5  gelf servers) as below

```
GELF_1_DEPLOYMENT=app01
GELF_1_HOST=gelf1.local
GELF_1_PORT=12201

GELF_2_DEPLOYMENT=app02
GELF_2_HOST=gelf2.local
GELF_2_PORT=12202
```

Parsing of standard nginx-ingress log is supported as well e.g
```
GELF_1_DEPLOYMENT=nginx-ingress
GELF_1_HOST=gelf1.local
GELF_1_PORT=12201
GELF_1_PARSE_NGINX: "yes"
```

## Testing with docker-compose

```
docker-compose build
docker-compose up
```


## Testing with kubernetes helm on minikube

* Building the image

```
make build
```

* Creating the chart

```
make install
```

* Deploying (or redeploying) the chart

```
make
```

* To cleanup the chart

```
make delete
OR
make clean
```
