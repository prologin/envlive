#!/bin/sh

help_string="Usage: $0 prololive.img /dev/device"
input_image=${1?$help_string}
output_device=${2?$help_string}

/usr/bin/dd status=progress bs=10M if="${1}" of="${2}" oflag=direct
