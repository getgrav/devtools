#!/bin/bash
GIT_FOLDERS=(`pwd`/*)

# update GIT projects
echo ""
echo "Updating GIT repositories"
echo "-------------------------"
for ((i = 0; i < ${#GIT_FOLDERS[@]}; i++))
do
    PROJECT=${GIT_FOLDERS[$i]}

    if [ -d "${PROJECT}/.git" ]; then
        echo "Updating '${GIT_FOLDERS[$i]}'"
        cd $PROJECT
        git pull
        echo ""
    fi
done;
