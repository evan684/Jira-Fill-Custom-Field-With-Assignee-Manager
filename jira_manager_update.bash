#!/bin/bash

AWSSECRET=$(aws secretsmanager get-secret-value --secret-id JIRA_AND_LDAP_CREDS_SECRET --region us-west-2 | jq -r .SecretString | jq .)
JIRAUSER="$(echo "${AWSSECRET}" | jq -r .JIRAUsername)"
JIRAPASS="$(echo "${AWSSECRET}" | jq -r .JIRAPassword)"
LDAPUSERNAME="$(echo "${AWSSECRET}" | jq -r .LDAPUsername)"
LDAPPASS="$(echo "${AWSSECRET}" | jq -r .LDAPPassword)"
BASESEARCH="OU=exampleOU,DC=corp,DC=example,DC=com"
DOMAINFQDN="corp.example.com"
JIRABASEURL="https://jira.example.com"
JIRAAUTHURL="https://jira.example.com/rest/auth/latest/session"
JIRASEARCHURL="https://jira.example.com/rest/api/2/search?jql="


# HTML endcode JQL search here.
ENCODEDJQL='Project%20%3D%20SE%20AND%20issuetype%20%3D%20%22AWS%20Crowdstrike%22%20AND%20status%20!%3D%20CLOSED'


managerSearch() {
    # This function grabs the user passed in as a paramater and returns the the users manager listed in ldap.
    USERNAME="$1"
    MANAGERPATH=$(ldapsearch -o ldif-wrap=no -LLL -x -H ldaps://$DOMAINFQDN:636 -D "${LDAPUSERNAME}@${DOMAINFQDN}" -w "$LDAPPASS" -b "${BASESEARCH}" "(&(objectClass=user)(samaccountname=${USERNAME}))" manager | grep manager)
    MANAGERCN=$(echo "${MANAGERPATH}" | sed 's/,.*//g' | cut -d '=' -f 2)
    MANAGEROU=$(echo "${MANAGERPATH}" | sed 's/^[^,]*,//g')
    # uncomment these for troubleshooting if needed
    #echo "Manager CN: ${MANAGERCN}"
    #echo "Manager OU: ${MANAGEROU}"
    local MANAGERUSERNAME="$(ldapsearch -o ldif-wrap=no -LLL -x -H ldaps://$DOMAINFQDN:636 -D "${LDAPUSERNAME}@${DOMAINFQDN}" -w "$LDAPPASS" -b "${MANAGEROU}" "(&(objectClass=user)(CN=$MANAGERCN))" samaccountname | grep sAMAccountName | cut -d ' ' -f 2)"
    echo "$MANAGERUSERNAME"
}


# This section is a pre authorization to prevent the script from spaming the jira api with failed auths.
JIRA_AUTH_ATTEMPT=$(curl -u "${JIRAUSER}:${JIRAPASS}" "$JIRAAUTHURL" --header 'Accept: application/json' -L | jq -r .name)

if [[ "$JIRA_AUTH_ATTEMPT" == $(echo "$JIRAUSER" | tr '[:upper:]' '[:lower:]') ]]; then
    echo "Jira auth passed."
else
    echo "Jira auth failed exiting."
    exit 1
fi 


# This grabs all tickets within the jql search passes it into an array.
TICKETS+=( $(curl -u "${JIRAUSER}:${JIRAPASS}" "${JIRASEARCHURL}${ENCODEDJQL}" --header 'Accept: application/json' -L |jq -rc '(.issues[] | [.key, .fields.assignee.name,"https://jira.example.com/browse/"+.key, .fields.customfield_13267.name])') )

# This is the actual work protion of the ticket. T, Assignee: ${ticket_assignee}, Manager: ${manager}, URL: ${ticket_url}"
for i in "${TICKETS[@]}"; do
    ticket_number=$(echo "$i"| jq -r .[0])
    ticket_assignee=$(echo "$i"| jq -r .[1])
    ticket_url=$(echo "$i"| jq .[2])
    currentlysetmanager=$(echo "$i"| jq -r .[3] | tr '[:upper:]' '[:lower:]')
    manager=$(managerSearch "$ticket_assignee")
    if [[ "$currentlysetmanager" != "$manager" ]]; then
        if [[ "$manager" == "" ]]; then
            manager="${ticket_assignee}"
        fi
        echo "Adjusting ticket: ${ticket_number}, Assignee: ${ticket_assignee}, Manager: ${manager}, URL: ${ticket_url}"
        curl --request PUT \
        --url "${JIRABASEURL}/rest/api/latest/issue/${ticket_number}" \
        --user "${JIRAUSER}:${JIRAPASS}" \
        --header 'Accept: application/json' \
        --header 'Content-Type: application/json' \
        --data "{
           \"fields\": {
               \"customfield_13267\":{\"name\":\"${manager}\"}
           }
        }"
    else
        echo "Manager Already Correct: ${ticket_number}, Assignee: ${ticket_assignee}, Manager: ${currentlysetmanager}, URL: ${ticket_url}"
    fi
done