#!/bin/bash

set -u

# style format
foreground="\e[38;5;"
background="\e[48;5;"
reset="\e[0m"
bold="\e[1m"
dim="\e[2m"
underline="\e[4m"
blink="\e[5m"
reverse="\e[7m"
hidden="\e[8m"

r_bold="\e[21m"
r_dim="\e[22m"
r_underline="\e[24m"
r_blink="\e[25m"
r_reverse="\e[27m"
r_hidden="\e[28m"

# color list
bright_green="42m"
bgn=${bright_green}
bright_blue="39m"
bbe=${bright_blue}
bright_cyan="51m"
bcn=${bright_cyan}
bright_purple="170m"
bpe=${bright_purple}
bright_black="238m"
bbk=${bright_black}
bright_red="196m"
brd=${bright_red}
bright_white="231m"
bwt=${bright_white}
bright_yellow="184m"
byw=${bright_yellow}

blue="26m"
cbe=${blue}
black="235m"
cbk=${black}
cyan="37m"
ccn=${cyan}
green="35m"
cgn=${green}
purple="163m"
cpe=${purple}
red="160m"
crd=${red}
white="7m"
cwe=${white}
yellow="11m"
cyw=${yellow}
