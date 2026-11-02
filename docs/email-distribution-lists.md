# Email distribution lists

Some backend emails go to a distribution list. A distribution list is a
Cognito group named `dl-<list>` in the identity user pool. Technical operators
add and remove recipients in the admin app (Distribution lists). Changes take
effect for the next email: the backend reads the list each time it sends.

| Email | Distribution list | Fallback env var |
|---|---|---|
| CDS data load (`TariffSynchronizer::Mailer#cds_updates`) | `dl-cds-updates` | `CDS_UPDATES_TO_EMAILS` |
| Differences report (`ReportsMailer#differences`) | `dl-differences-report` | `DIFFERENCES_TO_EMAILS` |
| Search reference changes (`ReportsMailer#search_reference_changes`) | `dl-search-references-report` | `SEARCH_REFERENCES_REPORT_TO_EMAILS` |
| Appendix 5a changes (`Appendix5aPopulatorService`) | `dl-cupid-team` | `CUPID_TEAM_TO_EMAILS` |
| Green lanes updates (`GreenLanesUpdatesPublisher::Mailer`) | `dl-green-lanes-updates` | `GREEN_LANES_UPDATE_EMAIL` |
| MyOTT action logs (`ActionLogMailer`) | `dl-myott-report` | `MYOTT_REPORT_EMAIL` |

`CDS_UPDATES_CC_EMAILS` is not a distribution list. It is still read from the
env var.

## How recipients are chosen

`DistributionListRecipients` reads the enabled members of the list with
Cognito `ListUsersInGroup` and returns their emails, sorted and without
duplicates.

- If the list has members, the email goes to them.
- If the list is empty, or Cognito cannot be read (for example, a timeout,
  access denied, or no `COGNITO_USER_POOL_ID`), the email goes to the
  fallback env var. The log has a
  `distribution_list.fallback group=<list> reason=<reason>` line.

The backend never stores, caches or logs the emails.

The fallback env vars are temporary. When production logs show no
`distribution_list.fallback` lines, remove the env vars and the fallback code.

## Configuration

- The sending services (UK and XI workers, backend job) need
  `COGNITO_USER_POOL_ID` in their configuration secret.
- Terraform (`terraform/iam.tf`) gives the task role
  `cognito-idp:ListUsersInGroup` on that pool when the secret has the pool ID.

`DistributionListRecipients` has a copy of the group name guard in
trade-tariff-admin's `DistributionListService`. Keep both the same.
