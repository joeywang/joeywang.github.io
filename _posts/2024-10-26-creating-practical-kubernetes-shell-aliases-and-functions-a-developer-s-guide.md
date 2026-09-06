---
layout: post
title: "Kubectl aliases and functions that actually save time"
description: "A set of kubectl aliases and shell functions for pod access, JSONPath queries, and log searching that cut real typing out of day-to-day Kubernetes work."
date: 2024-10-26 00:00 +0000
categories: [DevOps]
tags: [kubernetes, devops, productivity, linux]
---
<audio controls preload="metadata" src="/assets/audio/creating-practical-kubernetes-shell-aliases-and-functions-a-developer-s-guide-summary.ogg">
  Your browser does not support the audio element.
</audio>


`kubectl` verbosity slows down anything you do more than a few times a day. These are the aliases and functions I actually keep around, not a full cheat sheet.

## Base aliases

```bash
alias k="kubectl"
alias kg="kubectl get"
alias kd="kubectl describe"
alias kdel="kubectl delete"
alias kn="kubectl -n"

alias kgp="kubectl get pods"
alias kgpw="kubectl get pods -o wide"
alias kgpa="kubectl get pods --all-namespaces"

alias kc="kubectl config"
alias kcc="kubectl config current-context"
alias kcg="kubectl config get-contexts"
```

## JSONPath queries

The verbose `-o jsonpath` incantations are worth wrapping once and forgetting about:

```bash
alias kgpn="kubectl get pods -o jsonpath='{.items[*].metadata.name}'"
alias kgpi="kubectl get pods -o jsonpath='{.items[*].spec.containers[*].image}'"
alias kgps="kubectl get pods -o jsonpath='{range .items[*]}{.metadata.name}{\"\\t\"}{.status.phase}{\"\\n\"}{end}'"

function kpodinfo() {
    kubectl get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{range .spec.containers[*]}  - {.name}: {.image}{"\n"}{end}{"\n"}{end}'
}
```

## Getting a shell in the right pod

A raw `kubectl exec` needs the exact pod name, which changes on every deploy. `kexec` finds it by label pattern instead, and refuses to guess when the pattern matches more than one pod:

```bash
function kexec() {
    local ns="${1:-default}"
    local pod_pattern="$2"
    local cmd="${3:-bash}"
    local pod_count=$(kubectl get pods -n "$ns" | grep -c "$pod_pattern")

    if [ $pod_count -eq 0 ]; then
        echo "No pods found matching pattern: $pod_pattern"
        return 1
    elif [ $pod_count -gt 1 ]; then
        echo "Multiple pods found matching pattern: $pod_pattern"
        kubectl get pods -n "$ns" | grep "$pod_pattern"
        echo "Please specify a more precise pattern"
        return 1
    fi

    local pod=$(kubectl get pods -n "$ns" | grep "$pod_pattern" | awk '{print $1}')
    echo "Executing $cmd on pod: $pod"
    kubectl exec -it -n "$ns" "$pod" -- $cmd
}
```

For multi-container pods, add a container argument and list the options when it's missing:

```bash
function kexec_container() {
    local ns="${1:-default}"
    local pod="$2"
    local container="$3"
    local cmd="${4:-bash}"

    if [ -z "$container" ]; then
        echo "Available containers:"
        kubectl get pod "$pod" -n "$ns" -o jsonpath='{.spec.containers[*].name}'
        echo
        return 1
    fi

    kubectl exec -it -n "$ns" "$pod" -c "$container" -- $cmd
}
```

## Watching and searching logs

```bash
function kwatch_pods() {
    local ns="${1:-default}"
    kubectl get pods -n "$ns" -w -o custom-columns=\
NAME:.metadata.name,\
STATUS:.status.phase,\
READY:.status.containerStatuses[0].ready,\
RESTARTS:.status.containerStatuses[0].restartCount,\
AGE:.metadata.creationTimestamp
}

function klogs_all() {
    local ns="${1:-default}"
    local label="$2"
    local pods=$(kubectl get pods -n "$ns" -l "$label" -o name)
    for pod in $pods; do
        kubectl logs -f "$pod" -n "$ns" &
    done
    wait
}

function klogs_search() {
    local ns="${1:-default}"
    local pattern="$2"
    local since="${3:-1h}"
    kubectl get pods -n "$ns" -o name | while read -r pod; do
        echo "=== $pod ==="
        kubectl logs --since=$since "$pod" -n "$ns" | grep -i "$pattern"
    done
}
```

## Context switching and cleanup

```bash
function kctx() {
    if [ $# -eq 0 ]; then
        kubectl config get-contexts
    else
        kubectl config use-context "$1"
        [ -n "$2" ] && kubectl config set-context --current --namespace="$2"
    fi
}

function kcleanup() {
    local ns="${1:-default}"
    kubectl delete pods --field-selector=status.phase=Succeeded -n "$ns"
    kubectl delete pods --field-selector=status.phase=Failed -n "$ns"
}
```

Bash and Zsh disagree on array syntax, so a function that picks a pod interactively needs a slightly different body in each. If you want it to work in both, skip arrays and read pod names line by line instead:

```bash
function compatible_kexec() {
    kubectl get pods -n "$1" -o name | while read -r pod; do
        pod=${pod##*/}
        kubectl exec -it -n "$1" "$pod" -- bash
        break
    done
}
```

None of this replaces knowing `kubectl` itself. It just removes the typing tax for the ten commands you run fifty times a day.
