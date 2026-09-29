#!/bin/bash

###############################################################################
# Kubernetes Log Scanner
###############################################################################

set -euo pipefail

clear

echo "============================================================"
echo "         Kubernetes Log Scanner"
echo "============================================================"

###############################################################################
# SELECT NAMESPACE
###############################################################################

while true; do

    echo ""
    echo "Available Namespaces:"
    echo "------------------------------------------------------------"

    NAMESPACE_ARRAY=("ALL_NAMESPACES")

    while IFS= read -r ns; do
        [ -n "$ns" ] && NAMESPACE_ARRAY+=("$ns")
    done < <(
        kubectl get namespaces \
        -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' \
        | sort
    )

    for i in "${!NAMESPACE_ARRAY[@]}"; do
        printf "%3d) %s\n" "$((i+1))" "${NAMESPACE_ARRAY[$i]}"
    done

    echo ""

    read -rp "Select Namespace Number: " NS_CHOICE

    if [[ "$NS_CHOICE" =~ ^[0-9]+$ ]] &&
       [ "$NS_CHOICE" -ge 1 ] &&
       [ "$NS_CHOICE" -le "${#NAMESPACE_ARRAY[@]}" ]; then
        break
    fi

    echo "Invalid selection. Selection is mandatory."

done

SELECTED_NAMESPACE="${NAMESPACE_ARRAY[$((NS_CHOICE-1))]}"

###############################################################################
# SELECT POD
###############################################################################

SELECTED_POD="ALL_PODS"

if [ "$SELECTED_NAMESPACE" != "ALL_NAMESPACES" ]; then

    while true; do

        echo ""
        echo "Pods in Namespace: $SELECTED_NAMESPACE"
        echo "------------------------------------------------------------"

        POD_ARRAY=("ALL_PODS")

        while IFS= read -r pod; do
            [ -n "$pod" ] && POD_ARRAY+=("$pod")
        done < <(
            kubectl get pods -n "$SELECTED_NAMESPACE" \
            -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' \
            | sort
        )

        for i in "${!POD_ARRAY[@]}"; do
            printf "%3d) %s\n" "$((i+1))" "${POD_ARRAY[$i]}"
        done

        echo ""

        read -rp "Select Pod Number: " POD_CHOICE

        if [[ "$POD_CHOICE" =~ ^[0-9]+$ ]] &&
           [ "$POD_CHOICE" -ge 1 ] &&
           [ "$POD_CHOICE" -le "${#POD_ARRAY[@]}" ]; then
            break
        fi

        echo "Invalid selection. Selection is mandatory."

    done

    SELECTED_POD="${POD_ARRAY[$((POD_CHOICE-1))]}"

fi

###############################################################################
# SEARCH VALUE
###############################################################################

while true; do

    echo ""
    read -rp "Enter Search Value (Flow ID / Transaction ID / Keyword): " SEARCH_VALUE

    if [ -n "$SEARCH_VALUE" ]; then
        break
    fi

    echo "Search value is mandatory."

done

###############################################################################
# BUILD NAMESPACE LIST
###############################################################################

if [ "$SELECTED_NAMESPACE" = "ALL_NAMESPACES" ]; then

    NAMESPACE_LIST=$(kubectl get ns \
        -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}')

else

    NAMESPACE_LIST="$SELECTED_NAMESPACE"

fi

###############################################################################
# START SCAN
###############################################################################

echo ""
echo "============================================================"
echo "SCAN CONFIGURATION"
echo "============================================================"
echo "Namespace : $SELECTED_NAMESPACE"

if [ "$SELECTED_NAMESPACE" != "ALL_NAMESPACES" ]; then
    echo "Pod       : $SELECTED_POD"
fi

echo "Search    : $SEARCH_VALUE"
echo "============================================================"
echo ""

MATCH_FOUND=0

for NS in $NAMESPACE_LIST; do

    echo ""
    echo "Scanning Namespace: $NS"
    echo "------------------------------------------------------------"

    if [ "$SELECTED_NAMESPACE" != "ALL_NAMESPACES" ] &&
       [ "$SELECTED_POD" != "ALL_PODS" ]; then

        POD_LIST="$SELECTED_POD"

    else

        POD_LIST=$(kubectl get pods -n "$NS" \
            -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}')

    fi

    for POD in $POD_LIST; do

        echo "Checking Pod: $POD"

        CONTAINERS=$(kubectl get pod "$POD" -n "$NS" \
            -o jsonpath='{.spec.containers[*].name}')

        for CONTAINER in $CONTAINERS; do

            echo "  Container: $CONTAINER"

            MATCHES=$(kubectl logs \
                "$POD" \
                -n "$NS" \
                -c "$CONTAINER" \
                --tail=-1 \
                2>/dev/null | grep -i "$SEARCH_VALUE" || true)

            if [ -n "$MATCHES" ]; then

                MATCH_FOUND=1

                echo ""
                echo "************************************************************"
                echo "MATCH FOUND"
                echo "Namespace : $NS"
                echo "Pod       : $POD"
                echo "Container : $CONTAINER"
                echo "************************************************************"

                echo "$MATCHES"

                echo "************************************************************"
                echo ""

            fi

        done

    done

done

###############################################################################
# SUMMARY
###############################################################################

echo ""
echo "============================================================"
echo "SCAN COMPLETED"
echo "============================================================"

if [ "$MATCH_FOUND" -eq 0 ]; then
    echo "No matches found for: $SEARCH_VALUE"
else
    echo "Search completed successfully."
fi

echo "============================================================"
