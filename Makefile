####################################
# Build GOLANG based executables
####################################

### PLATFORM ########################################################################################################
ifeq (Darwin, $(findstring Darwin, $(shell uname -a)))
  PLATFORM := OSX
  OS := darwin
else
  PLATFORM := Linux
  OS := linux
endif

### ARCH ############################################################################################################
ARCH := amd64
# ARCH:=$(shell uname -p)

### GITHUB ##########################################################################################################
GITHUB_ACCOUNT=roscopecoltran
GITHUB_NAMESPACE=etcdtool

### APP #############################################################################################################
NAME=$(GITHUB_NAMESPACE)
BUILDDIR=.build
SRCDIR=github.com/$(GITHUB_ACCOUNT)/$(NAME)
VERSION:=$(shell git describe --abbrev=0 --tags)
RELEASE:=$(shell date -u +%Y%m%d%H%M)

### RUN #############################################################################################################
.PHONY: run
run:
	@go run main.go 

### BUILD ###########################################################################################################
.PHONY: build
build:
	@go build -o $(CURDIR)/dist/e3w-local main.go

### DIST ############################################################################################################
.PHONY: dist
dist:
	gox -verbose -os="darwin linux" -arch="amd64" -output="./dist/e3w-{{.OS}}" $(glide novendor)

### DEPS ############################################################################################################
.PHONY: deps
deps:
	@go get -v -u github.com/Masterminds/glide
	@go get -v -u github.com/mitchellh/gox

### DOCKER-COMPOSE ##################################################################################################
.PHONY: compose
compose:
	@docker-compose up --remove-orphans e3w

all: build

clean:
	rm -rf bin pkg ${NAME} ${BUILDDIR} release

update:
	gb vendor update --all

deps:
	go get github.com/constabulary/gb/...

build: clean
	gb build

darwin:
	gb build
	mkdir release || true
	mv bin/etcdtool release/etcdtool-${VERSION}-${RELEASE}.darwin.x86_64

rpm:
	docker pull mickep76/centos-golang:latest
	docker run --rm -it -v "$$PWD":/go/src/$(SRCDIR) -w /go/src/$(SRCDIR) mickep76/centos-golang:latest make build-rpm

binary:
	docker pull mickep76/centos-golang:latest
	docker run --rm -it -v "$$PWD":/go/src/$(SRCDIR) -w /go/src/$(SRCDIR) mickep76/centos-golang:latest make build-binary
	mkdir release || true
	mv bin/etcdtool release/etcdtool-${VERSION}-${RELEASE}.linux.x86_64

set-version:
	sed -i .tmp "s/const Version =.*/const Version = \"${VERSION}\"/" src/${SRCDIR}/version.go
	rm -f src/${SRCDIR}/version.go.tmp

release: clean set-version darwin rpm binary

build-binary: deps
	gb build

build-rpm: deps
	gb build
	mkdir -p ${BUILDDIR}/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}
	cp bin/${NAME} ${BUILDDIR}/SOURCES
	sed -e "s/%NAME%/${NAME}/g" -e "s/%VERSION%/${VERSION}/g" -e "s/%RELEASE%/${RELEASE}/g" \
		${NAME}.spec >${BUILDDIR}/SPECS/${NAME}.spec
	rpmbuild -vv -bb --target="${ARCH}" --clean --define "_topdir $$(pwd)/${BUILDDIR}" ${BUILDDIR}/SPECS/${NAME}.spec
	mkdir release || true
	mv ${BUILDDIR}/RPMS/${ARCH}/*.rpm release
