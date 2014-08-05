#!/bin/bash

# Script Vars
PID=0
CURRENT_PATH=`pwd`
DIST_PATH="${CURRENT_PATH}/grav-dist"
TMP_PATH="${CURRENT_PATH}/grav-tmp"
GRAV_CORE_PATH="${TMP_PATH}/grav"

# Github Vars
GRAV_PREFIX='grav-'
GRAV_TYPES=(plugin skeleton theme)
GRAV_CORE='https://github.com/getgrav/grav.git'
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



# Create the dist and tmp folders if don't exist already
mkdir -p ${DIST_PATH}
mkdir -p ${TMP_PATH}

# Start of output
echo ""
echo "Grav Build System"
echo "================="
echo ""

# Read user projects input
echo -n "Enter the project(s) (comma/space separated) that you want to build: "
read projects

# Start progress
progress "Finding projects on github"

# Convert to array the projects and check if exist
IFS=', ' read -a projects <<< "$projects"
PACKAGES_KEYS=('core')
PACKAGES_NAMES=('grav')
PACKAGES_VALUES=(${GRAV_CORE})

# Loops through projects and types and find the github URLS
for index in "${!projects[@]}"
do
    URL="${GITHUB}${projects[index]}.git"

    # Pinging github to ensure the project is there
    url_exists $URL
    EXISTS=$?
    if [ $EXISTS -eq 0 ]; then
        if [ ${projects[index]} == "grav" ]; then
            PACKAGES_KEYS+=('base')
        else
            PACKAGES_KEYS+=(${projects[index]})
        fi
        PACKAGES_NAMES+=(${projects[index]})
        PACKAGES_VALUES+=(${URL})
    fi

    for prefix in "${!GRAV_TYPES[@]}"
    do
        URL="${GITHUB}${GRAV_PREFIX}${GRAV_TYPES[prefix]}-${projects[index]}.git"

        # Pinging github to ensure the project is there
        url_exists $URL
        EXISTS=$?

        if [ $EXISTS -eq 0 ]; then
            PACKAGES_KEYS+=(${GRAV_TYPES[prefix]})
            PACKAGES_NAMES+=(${projects[index]})
            PACKAGES_VALUES+=(${URL})
        fi
    done
done
progress_stop $PID

# Exist if no project was found
if [ ${#PACKAGES_KEYS[@]} -eq 0 ]; then
    echo -e "...no project found."
    exit 0
fi

# Packages found, let's notify and continue
echo -en "...ok [$((${#PACKAGES_KEYS[@]} - 1))/${#projects[@]} found]\n\n"

# Loop through and clone
for index in "${!PACKAGES_KEYS[@]}"
do
    TYPE=${PACKAGES_KEYS[index]}
    NAME=${PACKAGES_NAMES[index]}
    URL=${PACKAGES_VALUES[index]}

    # Let's continue if it's grav base, since we hardocde it as first entry
    if [ "$NAME" == 'grav' -a  "${TYPE}" == 'base' ]; then
        continue
    fi

    progress "Cloning project '${NAME} (${TYPE})'"
    sleep 0.2

    if [ ! -d $TMP_PATH/$NAME ]; then
        git_clone $URL
    else
        echo -en ".skipped [exists]."
    fi

    # 0 base grav https://github.com/getgrav/grav.git
    echo -en "...done\n"
    progress_stop $PID
done

echo ""
# Building dists
for index in ${!PACKAGES_KEYS[@]}
do
    TYPE=${PACKAGES_KEYS[index]}
    NAME=${PACKAGES_NAMES[index]}
    URL=${PACKAGES_VALUES[index]}

    # We want to skip core, it's used only as a base for building other packages
    if [ "$NAME" == 'grav' -a  "${TYPE}" == 'core' ]; then
        continue
    fi

    # Build based on strategies
    progress "Building '${NAME}'"
    sleep 0.2

    # Let's change dir to dist

    case $TYPE in
        base)
            VERSION=$(head -n 1 ${GRAV_CORE_PATH}/VERSION)

            # Base grav package
            DEST="${DIST_PATH}/${GRAV_PREFIX}core"
            cp -Rf "$GRAV_CORE_PATH" "$DEST"
            create_zip "${DEST}-v${VERSION}.zip" "./${GRAV_PREFIX}core"
            rm -Rf $DEST

            # Grav package for updates (no user folder)
            DEST="${DIST_PATH}/${GRAV_PREFIX}core-update"
            cp -Rf "$GRAV_CORE_PATH" "$DEST"
            rm -rf "$DEST/user"
            create_zip "${DEST}-v${VERSION}.zip" "./${GRAV_PREFIX}core-update"
            rm -Rf $DEST
            ;;

        skeleton | theme | plugin)
            PREFIX=${GRAV_PREFIX}${TYPE}-${NAME}
            SOURCE=${TMP_PATH}/${PREFIX}
            DEST=${DIST_PATH}/${PREFIX}
            VERSION=$(head -n 1 ${SOURCE}/VERSION)

            if [ "$TYPE" == "skeleton" ]; then
                LOCATION="user"
            elif [ "$TYPE" == "theme" ]; then
                LOCATION="user/themes"
            elif [ "$TYPE" == "plugin" ]; then
                LOCATION="user/plugins"
            fi

            ## Skeleton Package with Grav wrapped
            # 1. Let's copy grav and delete the user folder if exists
            cp -Rf "$GRAV_CORE_PATH" "$DEST"

            # 2. Let's copy the skeleton in the Grav instance
            if [ "$TYPE" == "skeleton" ]; then
                rm -Rf "${DEST}/${LOCATION}"
                cp -Rf "$SOURCE" "$DEST/${LOCATION}"
            else
                rm -Rf "${DEST}/${LOCATION}/${NAME}"
                cp -Rf "$SOURCE" "$DEST/${LOCATION}/${NAME}"
            fi
            create_zip "$DEST-v${VERSION}.zip" "./${PREFIX}"
            rm -Rf $DEST
            ;;

        grav-learn)
            PREFIX=${NAME}
            SOURCE="${TMP_PATH}/${PREFIX}/user"
            DEST=${DIST_PATH}/${PREFIX}

            ## Skeleton Package with Grav wrapped
            # 1. Let's copy grav and delete the user folder if exists
            cp -Rf "$GRAV_CORE_PATH" "$DEST"
            rm -Rf "${DEST}/user"

            # 2. Let's copy the skeleton in the Grav instance
            cp -Rf "$SOURCE" "$DEST/user"

            create_zip "$DEST.zip" "./${PREFIX}"
            rm -Rf $DEST
            ;;

        *)
            echo "Strategy $TYPE for $NAME not implemented"
            exit 1
    esac

    echo -en "...done\n"

    progress_stop $PID

done

# end

echo ""
echo "All packages have been built and can be found at: "
echo -e "->  ${DIST_PATH}\n"
progress_stop $PID
rm -Rf $TMP_PATH # 2> /dev/null
echo ""
