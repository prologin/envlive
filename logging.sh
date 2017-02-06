tput_red=$(tput setaf 1)
tput_green=$(tput setaf 2)
tput_orange=$(tput setaf 3)
tput_reset=$(tput sgr0)

_log () {
    local color="${1}"
    shift
    echo "${color}>> ${@}${tput_reset}"
}

log () {
    _log "${tput_green}" "${@}"
}

warn () {
    _log "${tput_orange}" "${@}"
}

fail () {
    _log "${tput_red}" "${@}"
    return 1
}
