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
