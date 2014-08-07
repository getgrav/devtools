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

# Github Vars
GRAV_PREFIX='grav-'
GITHUB='https://github.com/getgrav/'


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
    echo -e "  -> No path was specified, assumed '${DEST}' \n"
fi

mkdir -p $DEST

echo -e "Cloning ${#GRAV_PROJECTS[@]} projects (this might take some time)...\n"

for project in ${!GRAV_PROJECTS[@]}
do
    URL="$GITHUB${GRAV_PROJECTS[$project]}.git"
    progress "    Grabbing ${GRAV_PROJECTS[project]} [$(($project + 1))/${#GRAV_PROJECTS[@]}]"
    git_clone $URL
    mv -f "$TMP_PATH/${GRAV_PROJECTS[$project]}" "$DEST/${GRAV_PROJECTS[$project]}"
    echo -en "...done\n"
    progress_stop $PID
done

# end

echo ""
echo "All packages have been cloned and can be found at: "
echo -e "->  ${DEST}\n"
progress_stop $PID
rm -Rf $TMP_PATH # 2> /dev/null
echo ""
