# Jira-Fill-Custom-Field-With-Assignee-Manager
This script pulls all the tickets in your specficed JQL search grabs the assignee runs it though an ldap search pulls the users manager and to the custom field called "manager" on the ticket.

I've used this script in conjuction with a Jira workflow automation that will re-assign the issue to the users manager on SLA breach.

As written this uses custom field ID: customfield_13267
You'll find this a in a couple of places in the script replace with your custom field ID as needed.

JQL search string variable must be html encoded.

This script requires the following packages:

    jq
    openldap-clients
    curl

If you have no LDAPS TLS certificate on the host add the following line to this file: /etc/openldap/ldap.conf TLS_REQCERT ALLOW

