# Jira-Fill-Custom-Field-With-Assignee-Manager
This bash script takes a specified JQL search string looks at the assignee of each ticket, performs an LDAP search to locate the users manager in AD and sets the manager in a custom field.

I've used this script in conjuction with a Jira workflow automation that will re-assign the issue to the users manager on SLA breach.
