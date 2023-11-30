#!/usr/bin/env bash

function kgp() {
    kubectl get pods $@
}
function kga() {
        kubectl get all $@
}
function kgs() {
        kubectl get service $@
}
function kgn() {
        kubectl get nodes -o wide $@
}
function kns() {
    kubectl config set-context --current --namespace $1
}
function kgns() {
    kubectl get namespaces
}
function kgnonly() {
    kubectl get nodes | awk 'NR!=1 {print $1}'
}
function kd() {
        kubectl describe $@
}
function kl() {
        kubectl logs $@
}
function ka() {
        kubectl apply $@
}
function ktp() {
        kubectl top pods $@
}
function kli() {
    kubectl get pods -o jsonpath='{range .items[*]}{"\n"}{.metadata.name}{":\t"}{range .spec.containers[*]}{.image}{", "}{end}{end}' | grep -v -e '^$' | grep -v latest
}
function kexec() {
    kubectl exec -it -- $@
}
function kc() {
    kubectl config use-context $1
}
function __refresh_kubecontexts() {
    complete -W "$(kubectl config get-contexts -o=name)" kc
}

function __kgnonly_complete() {
    local cur=${COMP_WORDS[COMP_CWORD]}
    COMPREPLY=( $(compgen -W "$(kgnonly)" -- $cur) )
}

function __kc_complete() {
    local cur=${COMP_WORDS[COMP_CWORD]}
    COMPREPLY=( $(compgen -W "$(kubectl config get-contexts -o=name)" -- $cur) )
}

function k.node.debug() {
    if [ -z "$1" ]; then
        echo -e "${WARNING}${RED} Node name not found: ${YELLOW}$1${NC}"
        return
    fi
    echo -e "${YELLOW}===========================================${NC}"
    echo -e "${ARROW}${CYAN} $1 ${YELLOW}: [${GREEN}${@:2}${YELLOW}] : ${SEA}$(TZ="America/Chicago" date)${NC}"
    echo -e "${YELLOW}===========================================${NC}"
    kubectl debug node/$1 -qit --image=mcr.microsoft.com/dotnet/runtime-deps:6.0 --target $1 -- chroot /host bash
}

complete -o nospace -F __kc_complete kc
omplete -o nospace -F __kgnonly_complete k.node.debug k.node.exec

