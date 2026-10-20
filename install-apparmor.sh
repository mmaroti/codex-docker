#!/usr/bin/env bash
# Generate from the installed Ubuntu/Debian Docker source, then install on host.
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
generate_only=false
uninstall=false
source_dir=
usage() {
    echo "Usage: $0 [--generate-only] [--source-dir EXTRACTED_DOCKER_SOURCE]"
    echo "       $0 --uninstall"
    echo 'Requires python3, Go, and (unless --source-dir is supplied) enabled APT source repositories.'
}
while (($#)); do
    case $1 in
        --generate-only) generate_only=true; shift ;;
        --uninstall) uninstall=true; shift ;;
        --source-dir) source_dir=$(realpath -- "${2:?Missing source directory}"); shift 2 ;;
        --help|-h) usage; exit 0 ;;
        *) usage >&2; exit 2 ;;
    esac
done
if $uninstall && { $generate_only || [[ -n $source_dir ]]; }; then
    echo '--uninstall cannot be combined with generation options.' >&2
    exit 2
fi
if [[ -e /.dockerenv ]]; then
    echo 'Run this installer on the Docker host, outside the container.' >&2
    exit 1
fi
if $uninstall; then
    for tool in sudo apparmor_parser; do
        command -v "$tool" >/dev/null || { echo "Missing prerequisite: $tool" >&2; exit 1; }
    done
    sudo -v
    loaded_profiles=$(sudo cat /sys/kernel/security/apparmor/profiles)
    if printf '%s\n' "$loaded_profiles" | grep -q '^codex-docker ('; then
        # Removal needs only the name, even if the installed source is missing.
        printf 'profile codex-docker {}\n' | sudo apparmor_parser --remove --skip-cache
    fi
    sudo rm -f -- /etc/apparmor.d/codex-docker.apparmor
    echo 'Unloaded codex-docker and removed /etc/apparmor.d/codex-docker.apparmor.'
    echo 'The generated repository copy and seccomp policy were retained.'
    exit 0
fi
for tool in python3 go; do
    command -v "$tool" >/dev/null || { echo "Missing prerequisite: $tool" >&2; exit 1; }
done
task_tmp=$(mktemp -d)
trap 'rm -rf -- "$task_tmp"' EXIT

if [[ -z $source_dir ]]; then
    command -v dockerd >/dev/null || { echo 'dockerd is not installed locally.' >&2; exit 1; }
    package=$(dpkg-query -S "$(command -v dockerd)" | head -n 1 | cut -d: -f1)
    source_spec=$(dpkg-query -W -f='${source:Package}=${source:Version}' "$package")
    echo "Obtaining matching package source: $source_spec"
    if ! (cd "$task_tmp" && apt-get source --only-source "$source_spec"); then
        echo 'Enable deb-src entries for your Ubuntu repositories and run sudo apt-get update.' >&2
        echo 'Alternatively supply an already extracted matching package with --source-dir.' >&2
        exit 1
    fi
    source_dir=$task_tmp
fi

# Use Go itself to render Docker's Go template; never execute package build scripts.
python3 - "$source_dir" "$task_tmp/template" <<'PY'
import pathlib, re, sys
root = pathlib.Path(sys.argv[1])
matches = []
for path in root.rglob('template.go'):
    if '.pc' in path.parts:  # Debian quilt's unpatched backups
        continue
    text = path.read_text()
    match = re.search(r'const\s+baseTemplate\s*=\s*`([^`]*)`', text, re.S)
    if match and 'deny mount,' in match[1] and 'profile {{.Name}}' in match[1]:
        matches.append((path, match[1]))
if len(matches) != 1:
    sys.exit(f'Expected one Docker AppArmor template, found {len(matches)}; refusing to guess.')
path, text = matches[0]
if len(re.findall(r'^\s*deny mount,\s*$', text, re.M)) != 1:
    sys.exit('Unfamiliar mount rule; refusing to patch.')
if not re.search(r'^\s*umount,\s*$', text, re.M):
    sys.exit('Expected existing umount permission; refusing to patch.')
text = re.sub(r'^(\s*)deny mount,\s*$', r'\1mount,\n  pivot_root,', text, count=1, flags=re.M)
pathlib.Path(sys.argv[2]).write_text(text)
print(f'Baseline: {path}')
PY

daemon_profile=unconfined
if ! $generate_only; then
    command -v apparmor_parser >/dev/null || { echo 'Install apparmor and apparmor-utils first.' >&2; exit 1; }
    command -v sudo >/dev/null || { echo 'Missing prerequisite: sudo' >&2; exit 1; }
    sudo -v
    mapfile -t daemon_pids < <(pgrep -x dockerd)
    if ((${#daemon_pids[@]} != 1)); then
        echo 'Expected exactly one local dockerd process; refusing to guess its AppArmor context.' >&2
        exit 1
    fi
    daemon_profile=$(sudo cat "/proc/${daemon_pids[0]}/attr/current")
    daemon_profile=${daemon_profile% (*)}
fi
cat > "$task_tmp/render.go" <<'GO'
package main
import ("os"; "strings"; "text/template")
func main() {
    exists := func(p string) bool { _, e := os.Stat("/etc/apparmor.d/" + p); return e == nil }
    imports := []string{"@{PROC}=/proc/"}
    if exists("tunables/global") { imports = []string{"#include <tunables/global>"} }
    inner := []string{}
    if exists("abstractions/base") { inner = append(inner, "#include <abstractions/base>") }
    abi := ""
    if exists("abi/3.0") { abi = "abi/3.0" }
    peer := os.Args[2]
    if peer != "unconfined" {
        if strings.ContainsAny(peer, "\"\\*?[]{}^,\n\r") { panic("Unsupported daemon profile name") }
        peer = "\"" + peer + "\""
    }
    data := map[string]any{"Name":"codex-docker", "PeerName":"codex-docker",
        "DaemonProfile":peer, "Imports":imports, "InnerImports":inner, "Abi":abi}
    raw, err := os.ReadFile(os.Args[1]); if err != nil { panic(err) }
    t, err := template.New("profile").Option("missingkey=error").Parse(string(raw)); if err != nil { panic(err) }
    if err = t.Execute(os.Stdout, data); err != nil { panic(err) }
}
GO
generated="$task_tmp/codex-docker.apparmor"
GO111MODULE=off GOTOOLCHAIN=local go run "$task_tmp/render.go" "$task_tmp/template" "$daemon_profile" > "$generated"
if $generate_only; then
    echo 'Generated for an unconfined daemon; installation detects its actual context.'
else
    # Compile without loading or writing parser caches before installing anything.
    sudo apparmor_parser --skip-kernel-load --skip-read-cache --skip-cache "$generated"
fi
install -m 0644 "$generated" "$script_dir/codex-docker.apparmor"
echo "Generated: $script_dir/codex-docker.apparmor"
if ! $generate_only; then
    sudo install -o root -g root -m 0644 "$generated" /etc/apparmor.d/codex-docker.apparmor
    sudo apparmor_parser -r /etc/apparmor.d/codex-docker.apparmor
    echo 'Installed and loaded profile codex-docker. Existing docker-default containers are unchanged.'
fi
