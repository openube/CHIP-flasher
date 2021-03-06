#!/bin/bash
OS=`uname`
KIVY=`which kivy`

# utility variables
red=`tput setaf 1`
green=`tput setaf 2`
yellow=`tput setaf 3`
blue=`tput setaf 4`
magenta=`tput setaf 5`
cyan=`tput setaf 6`
white=`tput setaf 7`
reset=`tput sgr0`

function header { echo "${yellow}====[ ${blue}${1} ${yellow}]====${reset}"; }
function info { echo "${yellow}==> ${white}${1}${reset}"; }
function error { echo "${yellow}==> ${red}${1}${reset}"; exit 1; }

function install_darwin {
	header "Installing for Darwin"

	# install kivy
	if [[ -z "$( which kivy )" ]]; then
		# find brew
		BREW=`which brew`
		if [[ -z "${BREW}" ]]; then
			error "brew command not found!"
		fi
		${BREW} install caskroom/cask/brew-cask || error "could not install cask!"
		${BREW} cask install kivy || error "could not install kivy!"
	fi

	# install libusb into kivy
	KIVY=`which kivy`
	SCRIPT_PATH="${KIVY}";
	if([ -h "${SCRIPT_PATH}" ]) then
	  while([ -h "${SCRIPT_PATH}" ]) do SCRIPT_PATH=`readlink "${SCRIPT_PATH}"`; done
	fi
	SCRIPT_PATH=$(python -c "import os; print os.path.realpath(os.path.dirname('${SCRIPT_PATH}'))")
	
	if [[ ! -f "${SCRIPT_PATH}/lib/libusb-1.0.dylib" ]]; then
		TMP_PATH=`mktemp -d -t chipflasher.XXXXXX`

		pushd $TMP_PATH
			git clone https://github.com/libusb/libusb.git
			pushd libusb
				./autogen.sh
				./configure --disable-dependency-tracking --prefix="${SCRIPT_PATH}"
				make -j4
				make install
			popd
		popd
	fi
	${KIVY} -m pip install libusb1 || error "could not install libusb1!"


}
function install_linux {
	function install_package {
		PACKAGE_MANAGER=`which apt-get`
		if [[ ! -z "${PACKAGE_MANAGER}" ]]; then
			${PACKAGE_MANAGER} --yes --force-yes install ${@} || \
				error "could not install ${@}!"
		fi
	}
	function install_package_repo {
		if [[ ! -z "$(which add-apt-repository)" ]]; then
			sudo add-apt-repository -y ${1} && \
			sudo apt-get -y update || \
				error "could not add repo ${1}!"
		fi
	}
	header "Installing for Linux"
	export DISPLAY=:0

	if [[ -z "$( which teamviewer)" ]]; then
		install_package libc6:i386 \
						libgcc1:i386 \
						libasound2:i386 \
						libexpat1:i386 \
						libfontconfig1:i386 \
						libfreetype6:i386 \
						libjpeg62:i386 \
						libpng12-0:i386 \
						libsm6:i386 \
						libxdamage1:i386 \
						libxext6:i386 \
						libxfixes3:i386 \
						libxinerama1:i386 \
						libxrandr2:i386 \
						libxrender1:i386 \
						libxtst6:i386 \
						zlib1g:i386
		wget "http://download.teamviewer.com/download/teamviewer_i386.deb"
		dpkg -i "teamviewer_i386.deb"
		rm -y "teamviewer_i386.deb"
	fi
	if [[ -z "$( which pip )" ]]; then
		install_package python-pip \
						python-dev
	fi
	if [[ -z "$( which gcc )" ]]; then
		install_package build-essential
	fi
	if [[ -z "$( which mkimage )" ]]; then
		install_package u-boot-tools
	fi
	if [[ -z "$(which git)" ]]; then
		install_package git
	fi
	if [[ -z "$(which gksu)" ]]; then
		install_package gksu
	fi
	if [[ -z "$(which fastboot)" ]]; then
		install_package android-tools-fastboot
	fi
	if [[ -z "$( which kivy )" ]]; then
		install_package mesa-common-dev \
						libgl1-mesa-dev \
						python-setuptools \
						python-pygame \
						python-opengl \
						python-gst0.10 \
						python-enchant \
						gstreamer0.10-plugins-good \
						libgles2-mesa-dev \
						libusb-1.0-0-dev
		PIP=`which pip`
		${PIP} install --upgrade Cython==0.21 || error "could not install cython!"
		${PIP} install kivy || error "could not install kivy!"
		${PIP} install libusb1 || error "could not install libusb1!"
		sudo ln -s /usr/bin/python2.7 /usr/local/bin/kivy
	fi
	if [[ -z "$(which tmate)" ]]; then
		install_package software-properties-common && \
		install_package_repo ppa:nviennot/tmate && \
		install_package tmate || \
			error "Could not install tmate!"
	fi
}
function install_flasher {
	if [[ ! -d "flasher" ]];then
		git clone https://github.com/NextThingCo/CHIP-flasher.git flasher
	fi
	if [[ ! -d "flasher/tools" ]];then
		git clone https://github.com/NextThingCo/CHIP-tools flasher/tools
	fi
	if [[ ! -f "flasher/sunxi-tools/fel" ]];then
		if [[ ! -d "flasher/sunxi-tools" ]];then
			git clone https://github.com/linux-sunxi/sunxi-tools flasher/sunxi-tools
		fi
		if [[ "${OS}" == "Darwin" ]]; then
			if [[ -z "$(which fel)" ]]; then
				pushd flasher/sunxi-tools
					cat <<-EOF > fix-osx.patch
						diff --git a/include/endian_compat.h b/include/endian_compat.h
						index e463a52..a927bbd 100644
						--- a/include/endian_compat.h
						+++ b/include/endian_compat.h
						@@ -29,6 +29,9 @@
						 #define le32toh(x) CFSwapInt32LittleToHost(x)
						 #define htole16(x) CFSwapInt16HostToLittle(x)
						 #define le16toh(x) CFSwapInt16LittleToHost(x)
						+
						+
						+#define be32toh(x) CFSwapInt32BigToHost(x)
						 #else
						 #include <endian.h>
						 #endif

						diff --git a/fel.c b/fel.c
						old mode 100644
						new mode 100755
						index 98e8d89..5f55d34
						--- a/fel.c
						+++ b/fel.c
						@@ -1081,6 +1081,8 @@ int main(int argc, char **argv)
						 		aw_fel_execute(handle, uboot_entry);
						 	}
						 
						+	libusb_release_interface(handle, 0);
						+
						 #if defined(__linux__)
						 	if (iface_detached >= 0)
						 		libusb_attach_kernel_driver(handle, iface_detached);
					EOF
				patch -p1 < fix-osx.patch
				popd
			fi
		fi
		make -C flasher/sunxi-tools fel
		ln -s "$(pwd)/flasher/sunxi-tools/fel" /usr/local/bin/fel
	fi
	chmod -R 777 flasher
  
  if [[ "$(uname)" == "Linux" ]]; then
  	cp flasher/chip-flasher.desktop Desktop
  	chown $(logname):$(logname) Desktop/chip-flasher.desktop
  fi
}

case "${OS}" in
	Darwin) install_darwin; install_flasher ;;
	Linux)	install_linux; install_flasher ;;
esac
