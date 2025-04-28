#!/usr/bin/env bash
# shellcheck disable=SC2310 # die triggers SC2310
set -euxo pipefail

# This script performs CRUD operations on the kwinrulesrc file.
# It uses crudini to read, write, and delete sections and keys in the file.
#
# The CRUD operations translate to:
# upsert: Update or Insert a new rule
# delete: Remove a rule
# read: Read a rule
# list: List all rules by UUID
#

USAGE="Usage: $0 <kwinrulesrc_file> <command> <command-args>
Where <kwinrulesrc_file> is the path to the kwinrulesrc file,
<command> is one of [upsert|delete|read|list],
and <command-args> are the arguments for the command."

GENERAL_SECTION="General"

function stderr() {
    echo "$@" >&2
}

function exit_with_code() {
    local code="$1"
    code="${code:-1}"
    stderr "Exit code: ${code}"
    exit "${code}"
}

function die() {
    local message="$1"
    local code="${2:-1}"
    stderr "${message}"
    exit_with_code "${code}"
}

function are_we_in_a_virtualenv() {
    if [[ -z "${VIRTUAL_ENV}" ]]; then
        return 1
    else
        return 0
    fi
}

function is_crudini_installed() {
    if command -v crudini &> /dev/null; then
        return 0
    else
        return 1
    fi
}

function check_dependencies() {

    if ! is_crudini_installed; then
        die 1 "crudini is not installed."
    fi

    if ! are_we_in_a_virtualenv; then
        die 1 "This script should be run in a virtual environment."
    fi
}

function usage() {
    echo "${USAGE}"
    exit 1
}

# list_rules <file> # lists all rules in the file by UUID
function list_rules() {
    file="${1}"
    # Note: We want to make a list of all sections in the file, excluding the General section. This is done instead of getting the list of rules from the General section, because the General section is not always present.
    crudini --get --ini-options=nospace,sectionspace "${file}" | grep -v "${GENERAL_SECTION}"
}

# count_rules <file> # returns the number of rules in the file
function count_rules(){
    file="${1}"
    list_rules "${file}" | grep -cv "${GENERAL_SECTION}"
}

# generate_rules_line <file> # Generates a "rules" line for the file.
# In the General section, we want a line with the format:
# rules=<UUID1>,<UUID2>,<UUID3>
set_rules_line() {
    file="${1}"
    # Run list_rules separately to avoid masking its return value
    local rule_uuids_output
    rule_uuids_output=$(list_rules "${file}")
    mapfile -t rule_uuids <<< "${rule_uuids_output}"
    for uuid in "${rule_uuids[@]}"; do
        crudini --set --ini-options=nospace,sectionspace --list "${file}" "${GENERAL_SECTION}" rules "${uuid}"
    done
}

set_count_line() {
    file="${1}"
    count=$(count_rules "${file}")
    crudini --set --ini-options=nospace,sectionspace "${file}" "${GENERAL_SECTION}" count "${count}"
}

# update_general_section <file> # Updates the General section for the file.
update_general_section() {
    file="${1}"
    set_rules_line "${file}"
    set_count_line "${file}"
}

# read_rule <file> [uuid] # reads a rule from the file, in INI format. Useful for exporting. This function retrieves the specified rule based on its UUID.
# If no UUID is provided, it will return all rules in the file as an INI without a General section.
function read_rule() {
    file="${1}"
    if [[ -z "${2}" ]]; then
        # No UUID provided, return all rules
        crudini --get --ini-options=nospace,sectionspace --format=ini "${file}"
    else
        uuid="${2}"
        crudini --get --ini-options=nospace,sectionspace --format=ini "${file}" "${uuid}"
    fi
}

# upsert_rule <kwinrulesrc_file> <rule_file> # Upserts a rule into the kwinrulesrc_file by UUID, from the rule_file.
function upsert_rule() {
    kwinrulesrc_file="${1}"
    rule_file="${2}"
    # As it so happens, we can actually just use merge to do this.
    crudini --merge --ini-options=nospace,sectionspace "${kwinrulesrc_file}" < "${rule_file}"
    update_general_section "${kwinrulesrc_file}" # we need to update the General section after merging
}

# delete_rule <kwinrulesrc_file> <uuid> # Deletes a rule from the kwinrulesrc_file by UUID.
function delete_rule() {
    kwinrulesrc_file="${1}"
    uuid="${2}"
    crudini --del --ini-options=nospace,sectionspace "${kwinrulesrc_file}" "${uuid}"
    update_general_section "${kwinrulesrc_file}" # we need to update the General section after deleting
}

# Main function
function main() {
    if [[ $# -lt 2 ]]; then
        usage
    fi

    kwinrulesrc_file="${1}"
    command="${2}"
    shift 2

    check_dependencies

    case "${command}" in
        upsert)
            upsert_rule "${kwinrulesrc_file}" "$@"
            ;;
        delete)
            delete_rule "${kwinrulesrc_file}" "$@"
            ;;
        read)
            read_rule "${kwinrulesrc_file}" "$@"
            ;;
        list)
            list_rules "${kwinrulesrc_file}"
            ;;
        *)
            usage
            ;;
    esac
}
# Call the main function with all arguments
main "$@"
# End of file
# vim: set ts=4 sw=4 et: