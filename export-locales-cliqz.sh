#! /usr/bin/env bash

#
# Assumes the following is installed:
#
#  git
#  brew
#  python via brew
#  virtualenv via pip in brew
#
# Syntax is:
# ./export-locales-cliqz.sh (name of project file) (name of l10n repo) (name of xliff file) [clean]
#
# We can probably check all that for the sake of running this hands-free
# in an automated manner.
#

clean_run=false
if [ $# -ge 3 ]
then
    if [ $# -eq 4 ]
    then
        if [ "$4" == "clean" ]
        then
            clean_run=true
        else
            echo "Unknown parameter: $4"
            echo "Leave empty to reuse an existing venv, use 'clean' to create a new one"
            exit 1
        fi
    fi
    xcodeproj="$1"
    l10n_repo="$2"
    l10n_file="$3"
else
    echo "Not enough parameters."
    echo "Syntax: ./export-locales.sh (name of .xcodeproj file) (name of l10n repo) (name of xliff file) [clean]"
    echo "Example: ./export-locales.sh Client.xcodeproj firefoxios-l10n firefox-ios.xliff clean"
    echo "You should call this script via wrappers like export-locales-firefox.sh"
    exit 1
fi

if [ ! -d ${xcodeproj} ]
then
  echo "Please run this from the project root that contains ${xcodeproj}"
  exit 1
fi

if [ -d ${l10n_repo} ]
then
  echo "There already is a ${l10n_repo} checkout. Aborting to let you decide what to do."
  exit 1
fi

SDK_PATH=`xcrun --show-sdk-path`

SCRIPTS="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# If the virtualenv with the Python modules that we need doesn't exist,
# or a clean run was requested, create the virtualenv.
if [ ! -d export-locales-env ] || [ "${clean_run}" = true ]
then
    rm -rf export-locales-env || exit 1
    echo "Setting up new virtualenv..."
    virtualenv export-locales-env --python=python2.7 || exit 1
    source export-locales-env/bin/activate || exit 1
    # install libxml2
    CFLAGS=-I"$SDK_PATH/usr/include/libxml2" LIBXML2_VERSION=2.9.2 pip install lxml || exit 1
else
    echo "Reusing existing virtualenv found in export-locales-env"
    source export-locales-env/bin/activate || exit 1
fi

# Check out a clean copy of the l10n repo
git clone https://github.com/cliqz-oss/${l10n_repo} || exit 1

# Export English base to /tmp/en.xliff
rm -rf /tmp/en.xcloc || exit 1
echo "Exporting en-US with xcodebuild"
xcodebuild -exportLocalizations -localizationPath /tmp -project ${xcodeproj} -exportLanguage en || exit 1

if [ ! -f /tmp/en.xcloc/Localized\ Contents/en.xliff ]
then
  echo "Export failed. No /tmp/en.xcloc generated."
  exit 1
fi

# Create a branch in the repository
cd ${l10n_repo}
branch_name=$(date +"%Y%m%d_%H%M")
git branch ${branch_name}
git checkout ${branch_name}

# Copy the English XLIFF file into the repository and commit
cp /tmp/en.xcloc/Localized\ Contents/en.xliff en-US/${l10n_file} || exit 1

sed -i ""  "s/source-language=\"en\">/source-language=\"en\" target-language=\"en\">/g" en-US/${l10n_file}


# cleanup English locale
${SCRIPTS}/xliff-cliqz-cleanup.py ../${l10n_repo}/en-US/*.xliff || exit 1

# Update all locales
${SCRIPTS}/update-xliff.py . ${l10n_file} || exit 1


git commit -a -m "Updated localized files"


echo
echo "NOTE"
echo "NOTE Use the following command to push the branch to Github where"
echo "NOTE you can create a Pull Request:"
echo "NOTE"
echo "NOTE   cd ${l10n_repo}"
echo "NOTE   git push --set-upstream origin $branch_name"
echo "NOTE"
echo
