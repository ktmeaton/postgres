#!/bin/bash

{
    echo -e "# Host User information for non-root container usage"
    echo USER_ID=$(id -u)
    echo GROUP_ID=$(id -g)
    echo USER_GROUP_ID=$(id -u):$(id -g)

    echo -e "\n# PostgreSQL Superuser Credentials"
    echo POSTGRES_USER=postgres
    echo POSTGRES_PASSWORD=$(cat /dev/urandom | LC_CTYPE=C tr -dc 'a-zA-Z0-9' | head -c 50)

    echo -e "\n# PostgreSQL Non-Superuser Credentials"
    echo CUSTOM_USER=custom
    echo CUSTOM_PASSWORD=$(cat /dev/urandom | LC_CTYPE=C tr -dc 'a-zA-Z0-9' | head -c 50)
    echo CUSTOM_DB=custom

    echo -e "\n# PostgreSQL Timetable Credentials"
    echo TIMETABLE_USER=timetable
    echo TIMETABLE_PASSWORD=$(cat /dev/urandom | LC_CTYPE=C tr -dc 'a-zA-Z0-9' | head -c 50)
}
