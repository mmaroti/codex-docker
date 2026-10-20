#!/usr/bin/env bash
# Opt-in Lake adapter for Docker's masked /proc. This shares the container's
# process namespace and /proc; it is not a security boundary within Docker.
set -euo pipefail

args=()
while (($#)); do
    case $1 in
        --)
            args+=("$@")
            break
            ;;
        --proc)
            if [[ ${2:-} != /proc ]]; then
                echo 'comparator-bwrap: unsupported --proc target' >&2
                exit 2
            fi
            args+=(--ro-bind /proc /proc)
            shift 2
            ;;
        --unshare-all)
            # A borrowed procfs must use its original PID namespace. Lean's
            # executable discovery fails when the two namespaces disagree.
            args+=(--unshare-user --unshare-ipc --unshare-net --unshare-uts --unshare-cgroup-try)
            shift
            ;;
        --unshare-pid|--pidns|--as-pid-1)
            echo 'comparator-bwrap: PID isolation is incompatible with borrowed /proc' >&2
            exit 2
            ;;
        *) args+=("$1"); shift ;;
    esac
done
exec /usr/bin/bwrap "${args[@]}"
