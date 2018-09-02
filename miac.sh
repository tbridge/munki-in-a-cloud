#!/bin/bash

## This script is designed to setup a Munki repository on a local machine for sync to the cloud.

## Goals:
## This script should:

## Declare some useful variables:

AUTOPKG_LOCATION="/usr/local/bin/autopkg"
DEFAULTS_LOCATION="/usr/bin/defaults"
PIP_LOCATION="/usr/local/bin/pip"
PLISTBUDDY_LOCATION="/usr/libexec/PlistBuddy"
USERHOME="$HOME"
REPOLOC="/Users/Shared/"
REPONAME="munki_repo"
REPODIR="${REPOLOC}/${REPONAME}"
LOGGER="/usr/bin/logger -t Munki-in-a-Cloud"
MUNKILOC="/usr/local/munki"
MANU="/usr/local/munki/manifestutil"
TEXTEDITOR="BBEdit.app"
osvers=$(sw_vers -productVersion | awk -F. '{print $2}') # Thanks Rich Trouton
AUTOPKGRUN="AdobeFlashPlayer.munki Dropbox.munki Firefox.munki GoogleChrome.munki BBEdit.munki munkitools3.munki MakeCatalogs.munki"
AUTOPKGARRAY=($AUTOPKGRUN)
DEFAULTS="/usr/bin/defaults"
AUTOPKG="/usr/local/bin/autopkg"
MAINPREFSDIR="/Library/Preferences"
ADMINUSERNAME=$(id -nu)
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
GENERICUUID=$(uuidgen | tr '[A-Z]' '[a-z]') # UUID converted to use lower-case letters in place of upper-case.
BUCKET="$GENERICUUID-miac" # OR Fill in your very own bucket name. Bucket names must be unique and can contain lowercase letters, numbers, and hyphens.
DOMAIN="your.domainname.tld" # This should be one you can actually control...

## Functions used in the script

rootCheck() {
    # Check that the script is NOT running as root
    if [[ $EUID -eq 0 ]]; then
        echo "### AutoPkg's user-level processes should not be run as root," 
        echo "### so this script is NOT MEANT to run with root privileges."
        echo ""
        echo "### When needed, it will prompt for an admin account's password."
        echo "### This will allow sudo to run specific functions using root privileges."
        echo ""
        echo "### Script will now exit. Please try running it again without root privileges."
        echo ""
        exit 4 # Running as root.
    fi
}

adminCheck() {
    # Check that the script is being run by an account with admin rights
    if [[ -z $(id -nG | grep -ow admin) ]]; then
        echo "### This script may need to use sudo to run specific functions" 
        echo "### using root privileges. The $(id -nu) account does not have"
        echo "### administrator rights associated with it, so it will not be"
        echo "### able to use sudo."
        echo ""
        echo "### Script will now exit."
        echo "### Please try running this script again using an admin account."
        echo ""
        exit 5 # Running as non-admin.
    fi
}

installCommandLineTools() {
    # Installing the Xcode command line tools on 10.10 and later

    echo "### Installing git via installing the Xcode command line tools..."
    echo
    osx_vers=$(sw_vers -productVersion | awk -F "." '{print $2}')
    cmd_line_tools_temp_file="/tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress"

    # Installing the latest Xcode command line tools on 10.10.x or later.

    if [[ "$osx_vers" -ge 10 ]]; then
    
    	# Create the placeholder file which is checked by the softwareupdate tool 
    	# before allowing the installation of the Xcode command line tools.
    	
    	touch "$cmd_line_tools_temp_file"
    	
    	# Identify the correct update in the Software Update feed with "Command Line Tools" in the name for the OS version in question.
    	
    	cmd_line_tools=$(softwareupdate -l | awk '/\*\ Command Line Tools/ { $1=$1;print }' | grep "$osx_vers" | sed 's/^[[ \t]]*//;s/[[ \t]]*$//;s/*//' | cut -c 2-)
    	
    	# Check to see if the softwareupdate tool has returned more than one Xcode
    	# command line tool installation option. If it has, use the last one listed
    	# as that should be the latest Xcode command line tool installer.
    	
    	if (( $(grep -c . <<<"$cmd_line_tools") > 1 )); then
    	   cmd_line_tools_output="$cmd_line_tools"
    	   cmd_line_tools=$(printf "$cmd_line_tools_output" | tail -1)
    	fi
    	
    	# Install the command line tools
    	
    	sudo softwareupdate -i "$cmd_line_tools" --verbose
    	
    	# Remove the temp file
    	
    	if [[ -f "$cmd_line_tools_temp_file" ]]; then
    	  rm "$cmd_line_tools_temp_file"
    	fi
    else
        echo "Sorry, this script is only for use on OS X/macOS >= 10.10"
    fi
}

installAutoPkg() {

    # Install the latest release of AutoPkg

    AUTOPKG_LOCATION_LATEST=$(curl https://api.github.com/repos/autopkg/autopkg/releases | python -c 'import json,sys;obj=json.load(sys.stdin);print obj[0]["assets"][0]["browser_download_url"]')
    /usr/bin/curl -L -s "${AUTOPKG_LOCATION_LATEST}" -o "$USERHOME/autopkg-latest.pkg"

    ${LOGGER} "Installing AutoPkg"
    sudo installer -verboseR -pkg "$USERHOME/autopkg-latest.pkg" -target /
    
    # Clean up
    
    rm "$USERHOME/autopkg-latest.pkg"

    ${LOGGER} "AutoPkg Installed"
    echo
    echo "### AutoPkg Installed"
    echo
}

installMunkiTools() {

   ${LOGGER} "Grabbing and Installing the Munki Tools Because They Aren't Present"
   MUNKI_LATEST=$(curl https://api.github.com/repos/munki/munki/releases/latest | python -c 'import json,sys;obj=json.load(sys.stdin);print obj["assets"][0]["browser_download_url"]')
    
   curl -L "${MUNKI_LATEST}" -o "$USERHOME/munki-latest1.pkg"

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

    sudo /usr/sbin/installer -dumplog -verbose -applyChoiceChangesXML "/tmp/com.github.munki-in-a-box.munkiinstall.xml" -pkg "$USERHOME/munki-latest1.pkg" -target "/"

    ${LOGGER} "Installed Munki Admin and Munki Core packages"
    echo "Installed Munki packages"
    
    # Clean up
    
    rm "$USERHOME/munki-latest1.pkg"


}

installPythonPip() {
    # Get Python Pip install tool
    
    ${LOGGER} "Installing Python Pip install tool"
    sudo easy_install pip

    ${LOGGER} "Pip Installed"
    echo
    echo "### Pip Installed"
    echo
}

installPythonCryptographyModule() {
    # Install pyopenssl to add the cryptography module
    # needed by AutoPkg on macOS Sierra and later.
    
    ${LOGGER} "Installing Python PyOpenSSL module to add the cryptography module."
    pip install -I --user pyopenssl

    ${LOGGER} "PyOpenSSL Installed"
    echo
    echo "### PyOpenSSL Installed"
    echo
}

installAWSCLI() {
    # Install awscli, needed to work with S3
    
    ${LOGGER} "Installing awscli tool."
    curl "https://s3.amazonaws.com/aws-cli/awscli-bundle.zip" -o "$USERHOME/awscli-bundle.zip"
    unzip "$USERHOME/awscli-bundle.zip" -d "$USERHOME"
    sudo "$USERHOME/awscli-bundle/install" -i /usr/local/aws -b /usr/local/bin/aws
    
    # Clean up
    
    rm -rf "$USERHOME/awscli-bundle"
    rm "$USERHOME/awscli-bundle.zip"

    ${LOGGER} "AWSCLI Installed"
    echo
    echo "### AWSCLI Installed"
    echo
}

## Couple Checks first:



echo "First up: Are you an admin user? Checking on that..."

# Make sure that the script is not being run as root.

rootCheck

# Make sure that the script is being run by an admin account.

adminCheck

echo "Great! The $(id -nu) account is an admin account."
echo "Any follow-up password requests will be for sudo rights."

${LOGGER} "Starting up Munki in a Cloud..."


${LOGGER} "Starting checks..."

# Make sure the whole script stops if Control-C is pressed.
fn_terminate() {
    fn_log_error "Munki-in-a-Box has been terminated."
    exit 1
}
trap 'fn_terminate' SIGINT

echo "Do we have git installed?"

# Find git's installed location. There will be an executable stub
# binary available at /usr/bin/git, but that doesn't necessarily mean
# git is actually installed. Instead, without git installed, the stub
# binary will trigger a GUI window which requests the installation of
# install the Xcode command line tools.

# If Xcode.app is installed in /Applications, set /usr/bin/git as
# git's location.

if [[ -x "/Applications/Xcode.app/Contents/Developer/usr/libexec/git-core/git" ]]; then
   GIT_LOCATION="/usr/bin/git"

# If the Xcode command line tools are installed, set /usr/bin/git as
# git's location.

elif [[ -x "/Library/Developer/CommandLineTools/usr/libexec/git-core/git" ]]; then
   GIT_LOCATION="/usr/bin/git"

# If the standalone git is installed, set /usr/local/bin/git as
# git's location.

elif [[ -x "/usr/local/git/bin/git" ]]; then
   GIT_LOCATION="/usr/local/bin/git"

# Otherwise, explicitly set GIT_LOCATION to be a null value. 
# That will trigger the script to install the Xcode command line tools.

else
   GIT_LOCATION=""
fi



# Check for Xcode command line tools  and install if needed.
if [[ ! -x "$GIT_LOCATION" ]]; then
    installCommandLineTools
else
    ${LOGGER} "Git installed"
    echo "### Git Installed"
fi

# Check for Python pip installer tool and install if needed.
if [[ ! -x "$PIP_LOCATION" ]]; then
    installPythonPip
else
    ${LOGGER} "Pip installed"
    echo "### Pip Installed"
fi

# Get AutoPkg if not already installed
if [[ ! -x ${AUTOPKG_LOCATION} ]]; then
    installAutoPkg "${userhome}"
    
    # Clean up if necessary.
    
    if [[ -e "$USERHOME/autopkg-latest.pkg" ]]; then
        rm "$USERHOME/autopkg-latest.pkg"
    fi    
else
    ${LOGGER} "AutoPkg installed"
    echo "### AutoPkg Installed"
fi

# Check for Python cryptography module and install if needed.

if [[ $(pip list | awk '/cryptography/ {print $1}') = "" ]]; then
    installPythonCryptographyModule
else
    ${LOGGER} "Python cryptography module installed"
    echo "### PyOpenSSL Installed"
fi


## Check for Munki Tools and install if needed.

if [[ ! -x "$MUNKILOC/munkiimport" ]]; then
  installMunkiTools
else
  ${LOGGER} "Munki installed."
  echo "/usr/local/munki/munkiimport existed, so I am not reinstalling. Hope you really had Munki installed..."
fi  


## Build a local repository

mkdir -p "$REPODIR/catalogs"
mkdir -p "$REPODIR/manifests"
mkdir -p "$REPODIR/pkgs"
mkdir -p "$REPODIR/pkgsinfo"
mkdir -p "$REPODIR/icons"

# When later syncing to S3, empty folders will not be synced because
# S3 doesn't have a filesystem concept of directories. To avoid the
# problem and force the complete directory structure to sync, a hidden
# file named .miac will be placed in each directory.

touch "$REPODIR/catalogs/.miac"
touch "$REPODIR/manifests/.miac"
touch "$REPODIR/pkgs/.miac"
touch "$REPODIR/pkgsinfo/.miac"
touch "$REPODIR/icons/.miac"

# Make sure the logged-in user owns the Munki repo directory.

chmod -R a+rX,g+w "$REPODIR"

## Install autopkg 

installAutoPkg

####
# Configure AutoPkg for use with Munki
####


${DEFAULTS} write com.github.autopkg MUNKI_REPO "$REPODIR"

${AUTOPKG} repo-add recipes
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
    ${LOGGER} "Running ${AUTOPKGARRAY[$j]} recipe"
    ${AUTOPKG} run "${AUTOPKGARRAY[$j]}"
done

${LOGGER} "AutoPkg Run"
echo "AutoPkg has run"

####
# Install AutoPkgr from the awesome Linde Group!
####
${AUTOPKG} make-override AutoPkgr.install

${AUTOPKG} run local.install.AutoPkgr

${LOGGER} "AutoPkgr Installed"
echo "AutoPkgr Installed"

# Create AutoPkgr recipe list

mkdir "$USERHOME/Library/Application Support/AutoPkgr"

# Add all recipes to AutoPkgr's list of recipes

ls -A "$USERHOME/Library/AutoPkg/Cache" | grep -v plist | grep -v MakeCatalogs | grep -v AutoPkgr > "$USERHOME/Library/Application Support/AutoPkgr/recipe_list.txt"
ls -A "$USERHOME/Library/AutoPkg/Cache" | grep MakeCatalogs >> "$USERHOME/Library/Application Support/AutoPkgr/recipe_list.txt"


####
# Install Munki Admin App by the amazing Hannes Juutilainen
####

${AUTOPKG} make-override MunkiAdmin.install

${AUTOPKG} run local.install.MunkiAdmin

# Check for the awscli tool and install if needed.

if [[ ! -x ${AWS} ]]; then
    installAWSCLI
else
    ${LOGGER} "awscli installed"
    echo "### awscli Installed"
fi

## Configure the awscli settings

## First we have to add credentials to a specific file.

mkdir ~/.aws

echo "[default]" > ~/.aws/credentials
echo "aws_access_key_id = $AWSSECRETKEY" >> ~/.aws/credentials
echo "aws_secret_access_key = $AWSSECRETPASSWORD" >> ~/.aws/credentials

echo "[default]" > ~/.aws/config
echo "region = $AWSREGIONID" >> ~/.aws/config
echo "[preview]" >> ~/.aws/config
echo "cloudfront = true" >> ~/.aws/config

## Create the S3 bucket

echo "Creating S3 bucket named $BUCKET in $AWSREGIONID"

"$AWS" s3api create-bucket --acl private --bucket "$BUCKET" --region "$AWSREGIONID"

## Sync to the S3 bucket

echo "Synching $REPODIR with S3 bucket named $BUCKET in $AWSREGIONID"

"$AWS" s3 sync "$REPODIR" s3://"$BUCKET" --exclude '*.git/*' --exclude '.DS_Store' --delete

## Get a beer and go to the pub.