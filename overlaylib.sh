colon_join () {
    local IFS=':'
    echo "$*"
}
__overlay_list=( )
__overlay_mounted=''
__overlay_workdir='overlay_workdir'
__overlay_mount_hooks=( )
__overlay_umount_hooks=( )

__overlay_mount_command='mount'
__overlay_umount_command='umount'

overlay_list_add () {
    local nlist=( "${1}" )
    nlist+=( "${__overlay_list[@]}" )
    __overlay_list=( "${nlist[@]}" )
}

overlay_mount_hook_add () {
    __overlay_mount_hooks+=( "${1}" )
}

overlay_umount_hook_add () {
    __overlay_umount_hooks+=( "${1}" )
}

overlay_list () {
    printf '%s\n' "${__overlay_list[@]}"
}

overlay_umount() {
    for hook in "${__overlay_umount_hooks[@]}"; do
	"${hook}" "${__overlay_mounted}"
    done
    "${__overlay_umount_command}" "${__overlay_mounted}"
    __overlay_mounted=''
}

overlay_mount() {
    if [[ "${__overlay_mounted}" != '' ]]; then
        echo ">> overlay_mount: already mounted" 1>&2
        return 1
    fi

    if [[ "${#__overlay_list[@]}" == 0 ]]; then
        echo ">> overlay_mount: overlay_list is empty" 1>&2
        return 1
    fi

    if [[ "${#__overlay_list[@]}" == 1 ]]; then
        "${__overlay_mount_command}" --bind "${__overlay_list}" "${1}"
    else
	local lowerdirs=$(colon_join "${__overlay_list[@]: 1}")
	local upperdir="${__overlay_list[0]}"
	mkdir -p "${__overlay_workdir}"
	local mount_options="lowerdir=${lowerdirs},"\
"upperdir=${upperdir},"\
"workdir=${__overlay_workdir}"

	"${__overlay_mount_command}" \
	    -t overlay \
	    -o "${mount_options}" \
	    overlay "${1}"
    fi

    __overlay_mounted="${1}"
    for hook in "${__overlay_mount_hooks[@]}"; do
	"${hook}" "${__overlay_mounted}"
    done
}

overlay_stack () {
    local current_root="${__overlay_mounted}"

    if [[ "${current_root}" != '' ]]; then
	overlay_umount
    fi
    overlay_list_add "${1}"

    if [[ "${#}" > 1 ]]; then
	local nroot="${2}"
    else
	local nroot="${current_root}"
    fi

    overlay_mount "${nroot}"
}
