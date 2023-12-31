#!/bin/bash

set -euox pipefail

sudo apt-get update -y
sudo apt-get install ca-certificates curl gnupg lsb-release -y
f_docker_keyring=/usr/share/keyrings/docker-archive-keyring.gpg
if [ -f "$f_docker_keyring" ]; then
	sudo rm -f "$f_docker_keyring"
fi

distro=$(grep -oP '(?<=^ID=).+' /etc/os-release | tr -d '"')
curl -fsSL "https://download.docker.com/linux/$distro/gpg" | sudo gpg --dearmor -o "$f_docker_keyring"
echo "deb [arch=$(dpkg --print-architecture) signed-by=$f_docker_keyring] https://download.docker.com/linux/$distro $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io -y


# Add user
set +e
sudo groupadd docker || echo "Skipping 'sudo groupadd docker' as it already exists"
set -e
sudo usermod -aG docker $USER
echo "Trying to run docker login in a separate process as it's not possible to reload the group and continue executing the current script"

	
# Thanks https://medium.com/@sachin.d.shinde/docker-compose-in-container-optimized-os-159b12e3d117
token=$(curl --fail --silent --show-error --header  "Metadata-Flavor: Google" "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token")
token=$(echo "$token" | grep --extended-regexp --only-matching "(ya29.[0-9a-zA-Z._-]*)")

sudo runuser -l $USER <<EOF
	# Login to docker
	echo "Checking if curl is installed"
	(which curl &> /dev/null && echo "Curl is installed") || \
	    (echo "Installing curl" && \
	    apt-get update -y -qq > /dev/null && \
	    apt-get install -y -qq curl > /dev/null)
	
	
	# Fixes " error storing credentials - err: exit status 1, out: add is unimplemented"
	# As per https://github.com/docker/cli/issues/1136#issuecomment-491610567
	docker logout
	mv ~/.docker/config.json ~/.docker/config_old.json
	
	echo "$token" | docker login -u oauth2accesstoken --password-stdin europe-docker.pkg.dev > /dev/null
	echo "$token" | docker login -u oauth2accesstoken --password-stdin us-docker.pkg.dev > /dev/null
	echo "$token" | docker login -u oauth2accesstoken --password-stdin asia-docker.pkg.dev > /dev/null

EOF
	
echo "Done docker login"
