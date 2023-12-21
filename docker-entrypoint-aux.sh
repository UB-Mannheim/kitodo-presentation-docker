#!/bin/bash

# Some color variables:
CLR_B='\e[1;34m'    # Bold Blue
CLR_G='\e[32m'      # Green
CLR_R='\e[1;31m'    # Bold Red
NC='\e[0m'          # No Color


function printHeadline() {
    border=$(printf '%.0s-' $(seq 1 $(echo -n "$1" | wc -c))) # create a border of dashes
    echo " "
    echo -e " ${CLR_B}#" $border "#${NC}"
    echo -e " ${CLR_B}# $1 #${NC}"
    echo -e " ${CLR_B}#" $border "#${NC}"
    echo " "
}

function printInfoLine() {
    echo -e "${CLR_B}$1${NC}"
}

function printSuccessLine() {
    echo -e "${CLR_G}$1${NC}"
}

function printErrorLine() {
    echo -e "${CLR_R}$1${NC}"
}
