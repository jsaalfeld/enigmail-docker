#!/usr/bin/env bash

set -e
imageversion=$1 # Image Version, I use the hg tip of the gpg4win-automation repo
mountingdir=$2  # Directory to mount in docker, the directory where the repo is cloned in (normally pwd)
proxy=$3	# Proxy adress for apt-proxying
dockerargs=$4	# Docker arguments

if [[ -z $imageversion ]]; then
	imageversion=$(md5sum $(pwd)/Dockerfile | awk '{print $1}')
fi;
if [[ -z $mountingdir ]]; then
	mountingdir=$(pwd)
fi;
repository="enigmail"
name=$repository #Name is used for the Docker stuff, repository to keep track of the repo that has to build

# Just to go sure, if the repository isn't cloned, do so!
if [[ ! -d $mountingdir/$repository ]]; then
	echo "no $mountingdir/$repository folder found... cloning..."
	git clone git://git.code.sf.net/p/enigmail/source enigmail
fi;
# when proxy is set, set it in my env too (to pull docker images etc.)
if [[ ! -z "$proxy" ]]; then
	export http_proxy=$proxy
fi;
# Unfortunatley, you cant filter with docker ps for untagged images,
# so it has to be done that way around.
if [[ ! -z $(docker $dockerargs images | grep "^<none>" | awk '{print $3}') ]]; then
	echo "removing untagged images"
	docker $dockerargs rmi $(docker $dockerargs images | grep "^<none>" | awk '{print $3}') 
fi;
# with some sed magic, add the proxy to the Dockerfile
if [[ ! -z "$proxy" ]]; then
	baseimage=$(sed -n -e '/^FROM/p' Dockerfile)
	environment=/etc/environment
		rootreplacement="$baseimage\nENV http_proxy '$proxy'\n"'RUN export http_proxy=$HTTP_PROXY''\nRUN echo '"http_proxy=$proxy >> $environment"·
	sed -i 's,'"$baseimage"','"$rootreplacement"',' Dockerfile
fi;
# When an image of this $imageversion doens't exist. Try to delete everything that
# was in the same namespace before and rebuild the image
if [[ -z $(docker $dockerargs ps -aqf "ancestor=$name/$imageversion") ]]; then
	if [[ ! -z $(docker $dockerargs images | grep "$name") ]]; then
		echo "deleting obsolete images"
		docker $dockerargs rmi -f $(docker $dockerargs images | grep "$name" | awk '{print $3}')
	fi;
	if [[ ! -z $(docker $dockerargs ps -a | grep "$name" | awk '{print $1}') ]]; then
		echo "deleting obsolete containers"
		docker $dockerargs rm -f $(docker $dockerargs ps -a | grep "$name" | awk '{print $1}')
	fi;
	docker $dockerargs build -t $name/$imageversion .
fi;
docker $dockerargs run -v $mountingdir:/build --rm=false -i $name/$imageversion
# We always want to keep the last container, so docker doesn't need to rebuild all
# and everything
if [[ ! -z $(docker $dockerargs ps -aqf ancestor="$name/$imageversion"| tail -n +2) ]]; then
	echo "delete every container, but leave the last one"
	docker $dockerargs rm -f $(docker $dockerargs ps -aqf ancestor="$name/$imageversion"| tail -n +2)
fi;

