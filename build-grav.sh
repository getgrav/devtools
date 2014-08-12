#!/bin/bash

# Script Vars
PID=0
CURRENT_PATH=`pwd`
DIST_PATH="${CURRENT_PATH}/grav-dist"
TMP_PATH="${CURRENT_PATH}/grav-dist-tmp"
GRAV_CORE_PATH="${TMP_PATH}/grav"

# Colors
TEXTRESET=$(tput sgr0) # reset the foreground colour
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
BLUE=$(tput setaf 4)
BOLD=$(tput bold)

# Github Vars
GRAV_PREFIX='grav-'
YAML_PREFIX="deps_"
GRAV_TYPES=(plugin skeleton theme)
GRAV_CORE='https://github.com/getgrav/grav.git'
GITHUB='https://github.com/getgrav/'
BITBUCKET='https://bitbucket.org/rockettheme/'
BITBUCKET_CLONE='git@bitbucket.org:rockettheme/'

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
    status=$(curl --output /dev/null --location --silent --head --fail --write-out "%{http_code}" "$1")

    if [ $status -eq 200 -o $status -eq 401 ]; then
        return 1
    else
        return 0
    fi

    # curl --output /dev/null --location --silent --head --fail "$1"
    # return $?
}

# Clone a git repo
function git_clone(){
    cd $TMP_PATH
    git clone --quiet $1
}

# Create a zip of a package without extra files not needed
function create_zip(){
    cd $DIST_PATH
    zip -q -x *.git* -x *.DS_Store* -x *hebe.json* -x *.dependencies* -r $1 $2
}

# YAML parser
function parse_yaml() {
    local prefix=$2
    local s='[[:space:]]*' w='[a-zA-Z0-9_]*' fs=$(echo @|tr @ '\034')
    sed -ne "s|^\($s\)\($w\)$s:$s\"\(.*\)\"$s\$|\1$fs\2$fs\3|p" \
        -e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p"  $1 |
    awk -F$fs '{
        indent = length($1)/4;
        vname[indent] = $2;
        for (i in vname) {if (i > indent) {delete vname[i]}}
        if (length($3) > 0) {
            vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_")}
            printf("%s%s%s=\"%s\"\n", "'$prefix'",vn, $2, $3);
        }
    }'
}

# Dependencies downloader and installer
function dependencies_install(){
    if [ -f "${1}" ]; then
        echo "${2:-Installing dependencies:}"

        POINTER=""
        for line in $(parse_yaml "${1}" "deps_")
        do
            DEP_KEY=$(echo $line | cut -d "=" -f 1)
            DEP_VALUE=$(echo $line | cut -d "=" -f 2)
            DEP_TYPE=$(echo $DEP_KEY | cut -d "_" -f 2) # git
            DEP_NAME=$(echo $DEP_KEY | cut -d "_" -f 3) # breadcrumbs
            DEP_MODE=$(echo $DEP_KEY | cut -d "_" -f 4) # url|path|branch

            if [ "${DEP_TYPE}" != 'git' ]; then
                continue
            fi

            eval $line

            if [ "${POINTER}" != "${DEP_NAME}" ]; then
                declare "deps_git_parsed_$DEP_NAME"="name:$DEP_NAME;$DEP_MODE:$DEP_VALUE"
                POINTER=$DEP_NAME
            else
                TMP="deps_git_parsed_$DEP_NAME"
                declare "$TMP"+=";$DEP_MODE:$DEP_VALUE"
            fi
        done
    fi

    for k in ${!deps_git_parsed_*}; do

        VALUE=$(echo ${!k} | tr -d "\"")

        DEP_NAME=$(echo ${VALUE} | cut -d ";" -f 1 | cut -d ":" -f 2)
        DEP_URL=$(echo ${VALUE} | cut -d ";" -f 2 | cut -d ":" -f 2-)
        DEP_PATH=$(echo ${VALUE} | cut -d ";" -f 3 | cut -d ":" -f 2)
        DEP_BRANCH=$(echo ${VALUE} | cut -d ";" -f 4 | cut -d ":" -f 2)
        DEP_PREFIX=$(echo ${DEP_URL} | rev | cut -d "/" -f 1 | rev)
        DEP_TYPE=$(echo ${DEP_PREFIX} | cut -d "-" -f 2)

        echo -n  "  "
        progress "${BOLD}${BLUE}${DEP_NAME}${TEXTRESET} ${BLUE}[${DEP_TYPE}]${TEXTRESET}"

        if [ ! -d $TMP_PATH/$DEP_PREFIX ]; then
            cd $TMP_PATH
            git_clone ${DEP_URL/https\:\/\/bitbucket\.org\/rockettheme/git@bitbucket.org:rockettheme}
        fi

        mv -f "$TMP_PATH/$DEP_PREFIX" "$DEST/$DEP_PATH"

        echo -en "...${BOLD}${GREEN}done${TEXTRESET}\n"
        progress_stop $PID

        #echo "k: $k, v: $VALUE"
    done
}



# Create the dist and tmp folders if don't exist already
mkdir -p ${DIST_PATH}
mkdir -p ${TMP_PATH}

# Start of output
echo ""
echo "${YELLOW}${BOLD}Grav Build System${TEXTRESET}"
echo "================="
echo ""
echo "Some projects name examples:"
echo "  ${BLUE}${BOLD}grav${TEXTRESET}              [on github:    grav]"
echo "  ${BLUE}${BOLD}grav-demo-sampler${TEXTRESET} [on bitbucket: grav-demo-sampler]"
echo "  ${BLUE}${BOLD}antimatter${TEXTRESET}        [on github:    grav-theme-antimatter]"
echo "  ${BLUE}${BOLD}breadcrumbs${TEXTRESET}       [on github:    grav-plugin-breadcrumbs]"
echo "  ${BLUE}${BOLD}blog-site${TEXTRESET}         [on github:    grav-skeleton-blog-site]"
echo "  ${BLUE}${BOLD}grav-learn${TEXTRESET}        [on github:    grav-learn]"
echo ""

# Read user projects input
echo -n "Enter the project(s) name (comma/space separated) that you want to build: "
read projects

# Start progress
progress "Finding projects on GitHub and Bitbucket"

# Convert to array the projects and check if exist
IFS=', ' read -a projects <<< "$projects"
PACKAGES_KEYS=('core')
PACKAGES_NAMES=('grav')
PACKAGES_VALUES=(${GRAV_CORE})

# Loops through projects and types and find the github URLS
for index in "${!projects[@]}"
do
    URL="${GITHUB}${projects[index]}.git"
    BURL="${BITBUCKET}${projects[index]}"
    BCLONE="${BITBUCKET_CLONE}${projects[index]}.git"

    # Pinging github to ensure the project is there
    url_exists $URL
    EXISTS=$?

    # If not found on github we try Bitbucket
    if [ $EXISTS -eq 0 ]; then
        url_exists $BURL
        EXISTS=$?
        if [ $EXISTS -eq 1 ]; then URL=$BCLONE; fi
    fi

    if [ $EXISTS -eq 1 ]; then
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
        BURL="${BITBUCKET}${GRAV_PREFIX}${GRAV_TYPES[prefix]}-${projects[index]}"
        BCLONE="${BITBUCKET_CLONE}${GRAV_PREFIX}${GRAV_TYPES[prefix]}-${projects[index]}.git"

        # Pinging github to ensure the project is there
        url_exists $URL
        EXISTS=$?

        # If not found on github we try Bitbucket
        if [ $EXISTS -eq 0 ]; then
            url_exists $BURL
            EXISTS=$?
            if [ $EXISTS -eq 1 ]; then URL=$BCLONE; fi
        fi

        if [ $EXISTS -eq 1 ]; then
            PACKAGES_KEYS+=(${GRAV_TYPES[prefix]})
            PACKAGES_NAMES+=(${projects[index]})
            PACKAGES_VALUES+=(${URL})
        fi
    done
done
progress_stop $PID

# Exist if no project was found
if [ $((${#PACKAGES_KEYS[@]} - 1)) -eq 0 ]; then
    rm -Rf $TMP_PATH
    echo -e "...${RED}${BOLD}no project found${TEXTRESET}.\n"
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

    progress "Cloning project '${BLUE}${BOLD}${NAME} (${TYPE})${TEXTRESET}'"
    sleep 0.2

    if [ ! -d $TMP_PATH/$NAME ]; then
        git_clone $URL
    else
        echo -en ".${YELLOW}${BOLD}skipped${TEXTRESET} [exists]."
    fi

    echo -en "...${GREEN}${BOLD}done${TEXTRESET}\n"
    progress_stop $PID
done

echo -e "\n"

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
    progress "Prepping '${BLUE}${BOLD}${NAME}${TEXTRESET}' for building"
    sleep 0.2

    # Let's change dir to dist

    case $TYPE in
        base)
            VERSION="-v$(head -n 1 ${GRAV_CORE_PATH}/VERSION)"
            PREFIX="${GRAV_PREFIX%?}"

            # Base grav package
            DEST="${DIST_PATH}/$PREFIX"
            cp -Rf "$GRAV_CORE_PATH" "$DEST"

            # Grav package for updates (no user folder)
            ## This whille happen as special case in the deps down below
            ;;

        skeleton | theme | plugin)
            PREFIX=${GRAV_PREFIX}${TYPE}-${NAME}
            SOURCE=${TMP_PATH}/${PREFIX}
            DEST=${DIST_PATH}/${PREFIX}
            VERSION="-v$(head -n 1 ${SOURCE}/VERSION)"

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
            ;;

        grav-learn | grav-demo-sampler)
            PREFIX=${NAME}
            SOURCE=${TMP_PATH}/${PREFIX}
            DEST=${DIST_PATH}/${PREFIX}
            VERSION=""

            ## Skeleton Package with Grav wrapped
            # 1. Let's copy grav and delete the user folder if exists
            cp -Rf "$GRAV_CORE_PATH" "$DEST"
            rm -Rf "${DEST}/user"

            # 2. Let's copy the skeleton in the Grav instance
            cp -Rf "$SOURCE" "$DEST/user"
            ;;

        *)
            echo -n "..${RED}${BOLD}[strategy '$TYPE' not implemented]${TEXTRESET}.."
    esac

    echo -en "...${GREEN}${BOLD}done${TEXTRESET}\n"
    progress_stop $PID

    ## Dependencies
    if [ "$TYPE" == 'theme' -o "$TYPE" == 'plugin' ]; then
        if [ -f "${DEST}/.dependencies" ]; then
            dependencies_install "${DEST}/.dependencies" "Installing Grav dependencies:"
        fi
    fi

    dependencies_install "${TMP_PATH}/${PREFIX}/.dependencies"

    # Finally create the package
    create_zip "${DEST}${VERSION}.zip" "./${PREFIX}"

    if [ "$TYPE" == 'base' ]; then
        # special case for grav core, creating an update package with no user folder
        DEST_UPD="${DIST_PATH}/${PREFIX}-update"
        cp -Rf "$GRAV_CORE_PATH" "$DEST_UPD"
        rm -Rf "$DEST_UPD/user" "$DEST_UPD/logs" "$DEST_UPD/cache" "$DEST_UPD/images"
        create_zip "${DEST_UPD}${VERSION}.zip" "./${PREFIX}-update"

        rm -Rf $DEST_UPD
    fi

    rm -Rf $DEST


    echo -e "Package for '${BLUE}${BOLD}${NAME}${TEXTRESET}' has been created.\n"

done

# end

echo ""
echo "All packages have been built and can be found at: "
echo -e "->  ${YELLOW}${BOLD}${DIST_PATH}${TEXTRESET}\n"
progress_stop $PID
rm -Rf $TMP_PATH # 2> /dev/null
echo ""
