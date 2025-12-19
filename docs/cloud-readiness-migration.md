# Cloud Readiness to Clean Core Exemption Migration

If you're using the ABAP Cloud Readiness check "Usage of Released APIs" in ATC and have created exemptions for findings of this check, you might want to migrate these exemptions to the new Clean Core check "Usage of APIs".
This program gives you the option to perform this migration automatically.

## Requirements

- SAP_BASIS release 7.58 or higher (only on-premise and private cloud systems are supported)
- abapGit installed in your system ([installation guide](https://docs.abapgit.org/user-guide/getting-started/install.html))
- All necessary authorizations to execute the program and to approve ATC exemptions
- All SAP Notes required for the Clean Core checks implemented in ATC must be applied in your system ([SAP Note Analyzer file](https://me.sap.com/notes/3627152))

## Installation

Pull the source code with [abapGit](https://docs.abapgit.org/user-guide/getting-started/install.html) into your ABAP.
The program to migrate the exemptions is provided in the `Z` namespace and is called `zatc_cloud_rdnss_2_cln_core`.

## Required Authorizations

To start the program and to view migration information, basic developer authorizations (`S_DEVELOP`, `ACTVT` 03 and 16) are required.
To perform the migration or to undo a migration, additional authorizations to approve ATC exemptions are required (`S_Q_GOVERN`, `ACTVT` 31, `ATC_OTYPGO` 01).
In addition, you need to be set as an approver in transaction `ATC` -> `Maintain Approvers`.

## Execution Steps

**Performing the Migration**

1. Start the program `zatc_cloud_rdnss_2_cln_core` in transaction SE38.
2. On the initial screen, you can choose to either display migration information or to perform the migration.
3. If you choose to display migration information, the number of migratable exemptions will be shown. In addition, you can see information about previous migrations, if any, such as the number of exemptions that were created in the Clean Core check as part of this migration.
4. If you choose to perform the migration, all exemptions for findings of the Cloud Readiness check "Usage of Released APIs" will be migrated to exemptions for findings of the Clean Core check "Usage of APIs". There is one configuration option available. You can read more about that in the next section.

**Undoing a Migration**
1. Start the program `zatc_cloud_rdnss_2_cln_core` in transaction SE38.
2. On the initial screen, choose the option to undo a previous migration.

> [!WARNING]
> All exemptions created as part of the previous migration will be deleted. Migrations that were requested and approved by users manually will not be affected. If you've made changes to migrated exemptions after the migration (to the validity period, for example), these exemptions will be deleted as well.

## Configuration Options

When performing the migration, you can choose to generate exemptions with no restrictions.
This means that all exempted findings of the Cloud Readiness check will be exempted in the Clean Core check.

If you want exempted findings where there's a successor object available to show up again, you can choose to omit the successor codes.
In this case, only findings for which no successor object is available will be exempted in the Clean Core check.
This allows you to review the newly introduced findings for which a successor object is available and decide whether you want to exempt them or not.

## Additional Information

- The program only migrates exemptions for findings of the Cloud Readiness check "Usage of Released APIs" to exemptions for findings of the Clean Core check "Usage of APIs".
- Only exemptions that are valid and approved at the time of the migration are considered.
- The program creates exemptions in the Clean Core check with the same validity period as the original exemptions in the Cloud Readiness check.
