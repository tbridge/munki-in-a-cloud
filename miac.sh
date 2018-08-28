#!/bin/bash

## This script is designed to setup a Munki repository on a local machine for sync to the cloud.

## Goals:
## This script should:

## Declare some useful variables:

REPOLOC="/Users/Shared/"
REPONAME="munki_repo"
REPODIR="${REPOLOC}/${REPONAME}"
LOGGER="/usr/bin/logger -t Munki-in-a-Cloud"
MUNKILOC="/usr/local/munki"
GIT="/usr/bin/git"
MANU="/usr/local/munki/manifestutil"
TEXTEDITOR="BBEdit.app"
osvers=$(sw_vers -productVersion | awk -F. '{print $2}') # Thanks Rich Trouton
AUTOPKGRUN="AdobeFlashPlayer.munki Dropbox.munki Firefox.munki GoogleChrome.munki BBEdit.munki munkitools3.munki MakeCatalogs.munki"
AUTOPKGARRAY=($AUTOPKGRUN)
DEFAULTS="/usr/bin/defaults"
AUTOPKG="/usr/local/bin/autopkg"
MAINPREFSDIR="/Library/Preferences"
ADMINUSERNAME="ladmin"
SCRIPTDIR="/usr/local/bin"
HTPASSWD="YouNeedToChangeThis"
HOSTNAME="your.domain.com"
AWSSECRETKEY="YOUGOTTAFIXTHIS"
AWSSECRETPASSWORD="YOUGOTTAFIXTHIS"
AWSREGIONID="us-east-1"
AWSOUTPUT="json"
AWS="/usr/local/bin/aws"
TERRAFORM="/usr/local/bin/terraform"
YOURNAME="FILLMEIN" # Fill in your company or project name for use with the bucket var.
GENERICUUID=$(uuidgen)
BUCKET="$GENERICUUID-Generic" # OR Fill in your very own bucket name, just recognize it has to be globally unique for Amazon's S3.
DOMAIN="your.domainname.tld" # This should be one you can actually control...

## Couple Checks first:

echo "First up: Are you an admin user? Enter your password below:"

#Let's see if this works...
#This isn't bulletproof, but this is a basic test.
sudo whoami > /tmp/quickytest

if
	[[  $(cat /tmp/quickytest) == "root" ]]; then
	${LOGGER} "Privilege Escalation Allowed, Please Continue."
	else
	${LOGGER} "Privilege Escalation Denied, User Cannot Sudo."
	exit 6 "You are not an admin user, you need to do this an admin user."
fi

${LOGGER} "Starting up Munki in a Cloud..."


${LOGGER} "Starting checks..."

# Make sure the whole script stops if Control-C is pressed.
fn_terminate() {
    fn_log_error "Munki-in-a-Box has been terminated."
    exit 1
}
trap 'fn_terminate' SIGINT

if
    [[ $EUID -eq 0 ]]; then
   echo "This script is NOT MEANT to run as root. This script is meant to be run as an admin user. I'm going to quit now. Run me without the sudo, please."
    exit 4 # Running as root.
fi

## Do we have the Dev Tools?

if
    [[ ! -d /Applications/Xcode.app ]]; then
    echo "You need to install the Xcode command line tools. Let me get that for you, it'll just take a minute."

###
# This section written by Rich Trouton and embedded because he's awesome. Diet Coke++, Rich.
###

# Installing the Xcode command line tools on 10.7.x through 10.10.x
 
osx_vers=$(sw_vers -productVersion | awk -F "." '{print $2}')
cmd_line_tools_temp_file="/tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress"
 
# Installing the latest Xcode command line tools on 10.9.x, 10.10.x or 10.11.x
 
	if [[ "$osx_vers" -ge 9 ]] ; then
 
	# Create the placeholder file which is checked by the softwareupdate tool 
	# before allowing the installation of the Xcode command line tools.
	
	touch "$cmd_line_tools_temp_file"
	
	# Find the last listed update in the Software Update feed with "Command Line Tools" in the name
	
	cmd_line_tools=$(softwareupdate -l | awk '/\*\ Command Line Tools/ { $1=$1;print }' | tail -1 | sed 's/^[[ \t]]*//;s/[[ \t]]*$//;s/*//' | cut -c 2-)
	
	#Install the command line tools
	
	sudo softwareupdate -i "$cmd_line_tools" -v
	
	# Remove the temp file
	
		if [[ -f "$cmd_line_tools_temp_file" ]]; then
	  rm "$cmd_line_tools_temp_file"
		fi
	fi
fi


## Download the Munki Tools

if
    [[ ! -f $MUNKILOC/munkiimport ]]; then
    cd ${REPOLOC}
    ${LOGGER} "Grabbing and Installing the Munki Tools Because They Aren't Present"
    MUNKI_LATEST=$(curl https://api.github.com/repos/munki/munki/releases/latest | python -c 'import json,sys;obj=json.load(sys.stdin);print obj["assets"][0]["browser_download_url"]')
    
    curl -L "${MUNKI_LATEST}" -o munki-latest1.pkg

## Install The Munki Tools!

# Write a Choices XML file for the Munki package. We are installing the tools, but not the launchd nor the Managed Software Center App. Thanks Rich and Greg for the language!


/bin/cat > "/tmp/com.github.munki-in-a-box.munkiinstall.xml" << 'MUNKICHOICESDONE'

     <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
    <array>
        <dict>
                <key>attributeSetting</key>
                <integer>1</integer>
                <key>choiceAttribute</key>
                <string>selected</string>
                <key>choiceIdentifier</key>
                <string>core</string>
        </dict>
        <dict>
                <key>attributeSetting</key>
                <integer>1</integer>
                <key>choiceAttribute</key>
                <string>selected</string>
                <key>choiceIdentifier</key>
                <string>admin</string>
        </dict>
        <dict>
                <key>attributeSetting</key>
                <integer>0</integer>
                <key>choiceAttribute</key>
                <string>selected</string>
                <key>choiceIdentifier</key>
                <string>app</string>
        </dict>
        <dict>
                <key>attributeSetting</key>
                <integer>0</integer>
                <key>choiceAttribute</key>
                <string>selected</string>
                <key>choiceIdentifier</key>
                <string>launchd</string>
        </dict>
</array>
</plist>
MUNKICHOICESDONE

sudo /usr/sbin/installer -dumplog -verbose -applyChoiceChangesXML "/tmp/com.github.munki-in-a-box.munkiinstall.xml" -pkg "munki-latest1.pkg" -target "/"

    ${LOGGER} "Installed Munki Admin and Munki Core packages"
    echo "Installed Munki packages"

    else
        ${LOGGER} "Munki was already installed, I think, so I'm moving on"
        echo "/usr/local/munki/munkiimport existed, so I am not reinstalling. Hope you really had Munki installed..."

fi

osx_vers=$(sw_vers -productVersion | awk -F "." '{print $2}')
cmd_line_tools_temp_file="/tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress"

## Build a local repository

cd "$REPOLOC"
mkdir "${REPONAME}/catalogs"
mkdir "${REPONAME}/manifests"
mkdir "${REPONAME}/pkgs"
mkdir "${REPONAME}/pkgsinfo"
mkdir "${REPONAME}/icons"

chmod -R a+rX,g+w "${REPONAME}"

## Install autopkg 

AUTOPKG_LATEST=$(curl https://api.github.com/repos/autopkg/autopkg/releases | python -c 'import json,sys;obj=json.load(sys.stdin);print obj[0]["assets"][0]["browser_download_url"]')
curl -L "${AUTOPKG_LATEST}" -o autopkg-latest1.pkg

sudo installer -pkg autopkg-latest1.pkg -target /

${LOGGER} "AutoPkg Installed"
echo "AutoPkg Installed"

####
# Configure AutoPkg for use with Munki
####


${DEFAULTS} write com.github.autopkg MUNKI_REPO "$REPODIR"

${AUTOPKG} repo-add http://github.com/autopkg/recipes.git
${AUTOPKG} repo-add rtrouton-recipes
${AUTOPKG} repo-add jleggat-recipes
${AUTOPKG} repo-add timsutton-recipes
${AUTOPKG} repo-add nmcspadden-recipes
${AUTOPKG} repo-add jessepeterson-recipes

${DEFAULTS} write com.googlecode.munki.munkiimport editor "${TEXTEDITOR}"
${DEFAULTS} write com.googlecode.munki.munkiimport repo_path "${REPODIR}"
${DEFAULTS} write com.googlecode.munki.munkiimport pkginfo_extension .plist
${DEFAULTS} write com.googlecode.munki.munkiimport default_catalog testing

${LOGGER} "AutoPkg Configured"
echo "AutoPkg Configured"

# This makes AutoPkg useful on future runs for the admin user defined at the top. It copies & creates preferences for autopkg and munki into their home dir's Library folder, as well as transfers ownership for the ~/Library/AutoPkg folders to them.

plutil -convert xml1 ~/Library/Preferences/com.googlecode.munki.munkiimport.plist

## Download Things and put them into the Repo

####
# Get some Packages and Stuff them in Munki
####

aLen=${#AUTOPKGARRAY[@]}
echo "$aLen" "overrides to create"

for (( j=0; j<aLen; j++));
do
    ${LOGGER} "Adding ${AUTOPKGARRAY[$j]} override"
    ${AUTOPKG} make-override "${AUTOPKGARRAY[$j]}"
    ${LOGGER} "Added ${AUTOPKGARRAY[$j]} override"
done

${AUTOPKG} run -v "${AUTOPKGRUN}"

${LOGGER} "AutoPkg Run"
echo "AutoPkg has run"

## Install Repo Tools

####
# Install AutoPkgr from the awesome Linde Group!
####
${AUTOPKG} make-override AutoPkgr.install

${AUTOPKG} run AutoPkgr.install

${LOGGER} "AutoPkgr Installed"
echo "AutoPkgr Installed"

mkdir /Users/$ADMINUSERNAME/Library/Application\ Support/AutoPkgr
touch /Users/$ADMINUSERNAME/Library/Application\ Support/AutoPkgr/recipe_list.txt

echo "com.github.autopkg.munki.munkitools2
com.github.autopkg.munki.makecatalogs" > /Users/$ADMINUSERNAME/Library/Application\ Support/AutoPkgr/recipe_list.txt

####
# Install Munki Admin App by the amazing Hannes Juutilainen
####

${AUTOPKG} make-override MunkiAdmin.install

${AUTOPKG} run MunkiAdmin.install

## Install awscli

if [[ ! -d /usr/local/bin/pip ]]; then 
	easy_install pip
	pip install awscli --upgrade --user
	
else 
	
	pip install awscli --upgrade --user

fi


## Configure the awscli

## 		First we have to add credentials to a specific file.

mkdir ~/.aws

echo "[default]" >> ~/.aws/credentials
echo "aws_access_key_id = {$AWSSECRETKEY}" >> ~/.aws/credentials
echo "aws_secret_access_key = {$AWSSECRETPASSWORD}" >> ~/.aws/credentials

echo "[default]" >> ~/.aws/config
echo "region = {$AWSREGIONID}" >> ~/.aws/config
echo "[preview]" >> ~/.aws/config
echo "cloudfront = true" >> ~/.aws/config

## Create the S3 bucket

${AWS} s3api create-bucket --acl private --bucket "${BUCKET}" --region ${AWSREGIONID}

## Sync to the S3 bucket

${AWS} sync ${REPODIR} s3://"${BUCKET}" --exclude '*.git/*' --exclude '.DS_Store' --delete

## Get a beer and go to the pub.
