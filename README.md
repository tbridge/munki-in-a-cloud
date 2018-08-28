munki-in-a-cloud
==============

The goal of this script is to setup a basic munki repo with a simple script based on a set of common variables. I have placed defaults in these variables, but they are easily overridden and you should decide what they are.

This script is based upon [Munki-in-a-Box](https://github.com/tbridge/munki-in-a-box), the Demonstration Setup Guide for Munki, AutoPKG, and other sources. My sincerest thanks to The Mac Admins Community for being supportive and awesome.

### Pre-Requisites:

1) A Mac running 10.12 or later. 
2) An active AWS Account and appropriate credentials
3) A light understanding of CloudFront and S3.

### Directions for Use:

As if this were a swarm of bees, unless you have some experience with Munki and AWS, this script may be dangerous. And, unlike Munki-in-a-Box, this script could **cost you a substantial amount in storage fees**, so use it carefully and deliberately. This script carries no warranty or guarantee, and it is entirely possible that Very Bad Things could happen by accident.

1) Check variables in Lines 10-39
2) Double-check that you have the right credentials in Lines 31-34
3) ./miac.sh

If you do not make changes to the script before running it, the script may not run as intended. *Please double-check to make sure that you are comfortable with the variables' values.*

## Caveats: 

When you setup AutoPkgr, be sure to understand the security implications of giving that GUI app, and its associated launchdaemons, access to the keychain. You should really use a one-off account for those notifications, and not, say, the admin account to your Google Domain. Just sayin'.

### Included Tools & Projects:

## Munki

[Munki](https://github.com/munki/munki) is a client management solution for the Mac. I'm assuming you know a little bit about how Munki works by installing it via this script, but I would be remiss not to point you to [Munki's official documentation](https://github.com/munki/munki/wiki). It is mostly installed in /usr/local/munki

## MunkiAdmin

[MunkiAdmin](http://hjuutilainen.github.io/munkiadmin/) is Hannes Juutilainen's native GUI application for managing Munki repositories. It is super handy for those who prefer graphical interfaces to their inscrutable XML files.  It is installed in the /Applications/Utilities directory.

## AutoPkg

[AutoPkg](http://autopkg.github.io/autopkg/) is an automated updates tool, used primarily from the command line, or through AutoPkgr, to keep a set of application installers up to date, and part of your Munki repository. AutoPkg is recipe-based, which means anyone can write their own recipe list and make it available. We are importing the main recipe repository, but if you want to add your own later, the AutoPkg docs will tell you how. Autopkg is installed in the /usr/local/bin directory.

## AutoPkgr

[AutoPkgr](http://www.lindegroup.com/autopkgr) is the Linde Group's native GUI application used for managing AutoPkg's command line functionality. Specifically, you can configure it to periodically check for new updates, import those into your Munki repository, then email you about what new versions have been imported for testing. It is installed in the /Applications/Utilities directory.

## AWS CLI

The [Amazon Web Services Command Line Interface](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-started.html) has a lot of useful tools for manipulating your AWS environment from the command line. I'm choosing to install it with `pip`, and installing `pip` if it is not already installed. You can alter that section if you want to use another package manager.

### Changelog

**New in 0.1**

Everything old is new again!

Questions? Comments? Suggestions? Jeers? Please email me at tom@technolutionary.com
