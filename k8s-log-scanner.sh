#!/bin/bash

set -u -o pipefail

clear

echo "==============================================================="
echo " Kubernetes Incident Scanner"
echo "==============================================================="

###############################################################################
# NAMESPACE SELECTION
###############################################################################

while true; do

    echo
    echo "Available Namespaces"
    echo "---------------------------------------------------------------"

    NAMESPACE_ARRAY=("ALL_NAMESPACES")

    while IFS= read -r ns; do
        [[ -n "$ns" ]] && NAMESPACE_ARRAY+=("$ns")
    done < <(
        kubectl get ns \
        -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' |
        sort
    )

    for i in "${!NAMESPACE_ARRAY[@]}"; do
        printf "%3d) %s\n" "$((i+1))" "${NAMESPACE_ARRAY[$i]}"
    done

    echo
    read -rp "Select Namespace Number: " NS_CHOICE

    if [[ "$NS_CHOICE" =~ ^[0-9]+$ ]] &&
       (( NS_CHOICE >= 1 )) &&
       (( NS_CHOICE <= ${#NAMESPACE_ARRAY[@]} ))
    then
        break
    fi

    echo "Invalid selection."

done

SELECTED_NAMESPACE="${NAMESPACE_ARRAY[$((NS_CHOICE-1))]}"

###############################################################################
# POD SELECTION
###############################################################################

SELECTED_POD="ALL_PODS"

if [[ "$SELECTED_NAMESPACE" != "ALL_NAMESPACES" ]]; then

    while true; do

        echo
        echo "Pods in Namespace: $SELECTED_NAMESPACE"
        echo "---------------------------------------------------------------"

        POD_ARRAY=("ALL_PODS")

        while IFS= read -r pod; do
            [[ -n "$pod" ]] && POD_ARRAY+=("$pod")
        done < <(
            kubectl get pods -n "$SELECTED_NAMESPACE" \
            -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' |
            sort
        )

        for i in "${!POD_ARRAY[@]}"; do
            printf "%3d) %s\n" "$((i+1))" "${POD_ARRAY[$i]}"
        done

        echo
        read -rp "Select Pod Number: " POD_CHOICE

        if [[ "$POD_CHOICE" =~ ^[0-9]+$ ]] &&
           (( POD_CHOICE >= 1 )) &&
           (( POD_CHOICE <= ${#POD_ARRAY[@]} ))
        then
            break
        fi

        echo "Invalid selection."

    done

    SELECTED_POD="${POD_ARRAY[$((POD_CHOICE-1))]}"

fi

###############################################################################
# SEARCH VALUE
###############################################################################

while true; do

    echo
    read -rp "Enter Search Value: " SEARCH_VALUE

    if [[ -n "$SEARCH_VALUE" ]]; then
        break
    fi

    echo "Search value is mandatory."

done

###############################################################################
# TIME RANGE
###############################################################################

while true; do

    echo
    echo "Select Time Range"
    echo "---------------------------------------------------------------"
    echo "1) Last 15 Minutes"
    echo "2) Last 1 Hour"
    echo "3) Last 6 Hours"
    echo "4) Last 24 Hours"
    echo "5) Last 7 Days"
    echo "6) All Available Logs"
    echo

    read -rp "Select Option: " TIME_CHOICE

    case "$TIME_CHOICE" in
        1)
            LOG_TIME_ARG="--since=15m"
            TIME_TEXT="Last 15 Minutes"
            break
            ;;
        2)
            LOG_TIME_ARG="--since=1h"
            TIME_TEXT="Last 1 Hour"
            break
            ;;
        3)
            LOG_TIME_ARG="--since=6h"
            TIME_TEXT="Last 6 Hours"
            break
            ;;
        4)
            LOG_TIME_ARG="--since=24h"
            TIME_TEXT="Last 24 Hours"
            break
            ;;
        5)
            LOG_TIME_ARG="--since=168h"
            TIME_TEXT="Last 7 Days"
            break
            ;;
        6)
            LOG_TIME_ARG=""
            TIME_TEXT="All Available Logs"
            break
            ;;
        *)
            echo "Invalid selection."
            ;;
    esac

done

###############################################################################
# BUILD NAMESPACE LIST
###############################################################################

if [[ "$SELECTED_NAMESPACE" == "ALL_NAMESPACES" ]]; then

    NAMESPACE_LIST=$(kubectl get ns \
        -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}')

else

    NAMESPACE_LIST="$SELECTED_NAMESPACE"

fi

###############################################################################
# SUMMARY
###############################################################################

echo
echo "==============================================================="
echo "Scan Configuration"
echo "==============================================================="
echo "Namespace : $SELECTED_NAMESPACE"

if [[ "$SELECTED_NAMESPACE" != "ALL_NAMESPACES" ]]; then
    echo "Pod       : $SELECTED_POD"
fi

echo "Time      : $TIME_TEXT"
echo "Search    : $SEARCH_VALUE"
echo "==============================================================="

###############################################################################
# SCAN
###############################################################################

MATCH_FOUND=0

for NS in $NAMESPACE_LIST; do

    echo
    echo "Scanning Namespace: $NS"
    echo "---------------------------------------------------------------"

    if [[ "$SELECTED_NAMESPACE" != "ALL_NAMESPACES" ]] &&
       [[ "$SELECTED_POD" != "ALL_PODS" ]]; then

        POD_LIST="$SELECTED_POD"

    else

        POD_LIST=$(kubectl get pods -n "$NS" \
            -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}')
    fi

    for POD in $POD_LIST; do

        CONTAINERS=$(kubectl get pod "$POD" -n "$NS" \
            -o jsonpath='{.spec.containers[*].name}' 2>/dev/null)

        [[ -z "$CONTAINERS" ]] && continue

        for CONTAINER in $CONTAINERS; do

            echo "Checking: $NS / $POD / $CONTAINER"

            if [[ -n "$LOG_TIME_ARG" ]]; then

                LOG_OUTPUT=$(kubectl logs \
                    "$POD" \
                    -n "$NS" \
                    -c "$CONTAINER" \
                    $LOG_TIME_ARG \
                    2>/dev/null)

            else

                LOG_OUTPUT=$(kubectl logs \
                    "$POD" \
                    -n "$NS" \
                    -c "$CONTAINER" \
                    2>/dev/null)

            fi

            RESULT=$(echo "$LOG_OUTPUT" | grep -i -C 20 -- "$SEARCH_VALUE" || true)

            if [[ -n "$RESULT" ]]; then

                MATCH_FOUND=1

                echo
                echo "###############################################################"
                echo "# MATCH FOUND"
                echo "###############################################################"
                echo "Namespace : $NS"
                echo "Pod       : $POD"
                echo "Container : $CONTAINER"
                echo "###############################################################"
                echo

                echo "$RESULT"

                echo
                echo "###############################################################"

            fi

        done

    done

done

###############################################################################
# FINAL SUMMARY
###############################################################################

echo
echo "==============================================================="
echo "SCAN COMPLETED"
echo "==============================================================="

if [[ "$MATCH_FOUND" -eq 0 ]]; then
    echo "No matches found."
else
    echo "Matches found."
fi

echo "==============================================================="