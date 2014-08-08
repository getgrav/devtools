#!/bin/bash

# Projects List
GRAV_PROJECTS=(grav \
               grav-learn \
               grav-skeleton-blog-site \
               grav-theme-antimatter \
               grav-plugin-problems grav-plugin-sitemap grav-plugin-error grav-plugin-taxonomylist grav-plugin-simplesearch grav-plugin-random grav-plugin-pagination grav-plugin-feed grav-plugin-breadcrumbs
               )

# Script Vars
PID=0
CURRENT_PATH=`pwd`
CLONES_PATH="${CURRENT_PATH}/grav-clones"
TMP_PATH="${CURRENT_PATH}/grav-clones-tmp"
HEBE=`command -v hebe`

TEXTRESET=$(tput sgr0) # reset the foreground colour
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
BLUE=$(tput setaf 4)
BOLD=$(tput bold)


FORCE=0

# Github Vars
GRAV_PREFIX='grav-'
GITHUB='https://github.com/getgrav/'

# Getopts
while [[ $# -gt 0 ]]; do
    opt="$1"
    shift;
    current_arg="$1"

    if [[ "$current_arg" =~ ^-{1,2}.* ]]; then
        echo "WARNING: You may have left an argument blank. Double check your command."
    fi
    case "$opt" in
        "-f"|"--force") FORCE=1; shift;;
        *             ) echo "ERROR: Invalid option: \""$opt"\"" >&2
                        exit 1;;
    esac
done


# Progress notice method
function progress(){
    progress_start $1 &
    PID=$!

    # Trap the progress process so it stops on exit
    trap "progress_stop $PID; exit 0;" TERM EXIT

    return $PID
}

function progress_start(){
    echo -n $@

    while true
    do
        echo -n "."
        sleep 1
    done
}

function progress_stop(){
    exec 2>/dev/null
    kill $1
}

# Ping URL and returns 0 if exists
function url_exists(){
    curl --output /dev/null --location --silent --head --fail "$1"
    return $?
}

# Clone a git repo
function git_clone(){
    cd $TMP_PATH
    git clone --quiet $1
    cd $2
    for branch in `git branch -a | grep remotes | grep -v HEAD`; do
        git branch --quiet --track ${branch##*/} $branch
    done
    git fetch --quiet --all
    git pull --quiet --all
    git flow init -fd > /dev/null 2>&1
    cd $TMP_PATH
}

# Create a zip of a package without extra files not needed
function create_zip(){
    cd $DIST_PATH
    zip -q -x *.git* -x *.DS_Store* -r $1 $2
}


# Create the clones and tmp folders if don't exist already
mkdir -p ${CLONES_PATH}
mkdir -p ${TMP_PATH}

# Start of output
echo ""
echo "Grav Dev Setup System"
echo "====================="
echo ""

read -e -p "Specify the path where Grav projects should get cloned at [default: ./grav-clones]: " DEST

if [ -z $DEST ]; then
    DEST=$CLONES_PATH
    echo "  -> No path was specified, assumed '${DEST}'"
fi

# Let's fix the tilde that bash doesnt work very well with
DEST="${DEST/\~/$HOME}"

echo ""
mkdir -p $DEST


# Cloning from github
echo -e "Cloning ${#GRAV_PROJECTS[@]} projects (this might take some time)...\n"

for project in ${!GRAV_PROJECTS[@]}
do
    URL="$GITHUB${GRAV_PROJECTS[$project]}.git"
    progress "    Grabbing ${GRAV_PROJECTS[project]} [$(($project + 1))/${#GRAV_PROJECTS[@]}]"
    sleep 0.1

    if [ ! -d "$DEST/${GRAV_PROJECTS[$project]}" -o $FORCE -eq 1 ]; then
        rm -rf "$DEST/${GRAV_PROJECTS[$project]}"
        git_clone $URL ${GRAV_PROJECTS[$project]}
        mv -f "$TMP_PATH/${GRAV_PROJECTS[$project]}" "$DEST/${GRAV_PROJECTS[$project]}"
        echo -en "...${GREEN}${BOLD}done${TEXTRESET}"
    else
        echo -en "...${YELLOW}${BOLD}skipped${TEXTRESET}"
    fi

    echo -en "\n"
    progress_stop $PID
done

# Hebe registering
echo ""
echo -en "Hebe registering ${#GRAV_PROJECTS[@]} projects..."

if [ -z $HEBE ]; then
    echo -en "${BOLD}hebe${TEXTRESET} comand not found. Please install it.\n"
else
    echo -e "\n"
    for project in ${!GRAV_PROJECTS[@]}
    do
        progress "    Registering ${GRAV_PROJECTS[project]} [$(($project + 1))/${#GRAV_PROJECTS[@]}]"
        sleep 0.1

        if [ ! -f "$DEST/${GRAV_PROJECTS[$project]}/hebe.json" ]; then
            echo -n "...${YELLOW}${BOLD}skipped${TEXTRESET}"
        else
            hebe register "$DEST/${GRAV_PROJECTS[$project]}/hebe.json" +force > /dev/null 2>&1
            echo -n "...${GREEN}${BOLD}done${TEXTRESET}"
        fi

        echo -en "\n"
        progress_stop $PID
    done
fi



# end

echo ""
echo "All packages have been cloned and can be found at: "
echo -e "->  ${DEST}\n"
progress_stop $PID
rm -Rf $TMP_PATH # 2> /dev/null
echo ""
