# Azure Service Retirement – Impact Assessment Tool

This repository provides **Azure Resource Graph (ARG) queries** and a **PowerShell utility**
to help customers identify Azure resources that are impacted by specific Azure service retirements.
 
The PowerShell script automatically executes **read-only ARG queries** that are maintained in a
separate text file and outputs the results locally for customer review.

## What is included
 Inside folder Impact-Analyzer you will find
- `queries.txt`
  - A maintained set of Azure Resource Graph (KQL) queries
  - Each query corresponds to a specific Azure service retirement
  - Includes retirement metadata and a public “Learn more” URL
  - **Reviewed and refreshed on a regular cadence (every 2 weeks)**
 
- `Get-RetirementImpactedResources.ps1`
  - PowerShell script to execute the ARG queries
  - Aggregates results across subscriptions accessible to the signed-in user
  - Outputs results to console and/or CSV
 
---

## Prerequisites

1. **Azure CLI**
   - Install: https://learn.microsoft.com/cli/azure/install-azure-cli
   - Login before running the script:
     ```
     az login --environment AzureChinaCloud
     ```

2. **PowerShell** — Works with PowerShell 5.1+ (built-in on Windows)

## File Structure

Place the following files in the **same folder**:

```
YourFolder\
├── run-arg-queries.ps1   (Script)
└── queries.txt           (Query file, provided)
```

## Usage

- The script runs **only in the customer’s Azure tenant**
- Queries are executed using the **current user’s Azure context**
- All operations are **read-only**
- No resources are modified
- No data is transmitted outside the customer environment
 
---

## Output

- Console will display impacted resources for each retiring feature.
- If impacted resources are found, a CSV file `impactedresources.csv` will be generated in the same folder.
- If no resources are impacted, NO CSV file will be generated — this means your environment is not affected.

## Troubleshooting

**1. Execution Policy Error**

If you see "cannot be loaded because the file is not digitally signed":

```powershell
Unblock-File .\run-arg-queries.ps1
```

Or bypass for a single run:

```powershell
powershell -ExecutionPolicy Bypass -File .\run-arg-queries.ps1
```

**2. Azure CLI Not Logged In**

If you see authentication errors, please login first:

```
az login --environment AzureChinaCloud
```

**3. No Output File Generated**

This is expected when no resources are impacted. Check the console output — it should show "No resources impacted".

---

## Important notes
 
- This repository contains **maintained discovery utilities**, not ad-hoc samples
- There is **no SLA or official support guarantee**
- Customers are responsible for validating results before taking any action
- Azure access permissions determine what resources are visible
 
---
 
## Security & Compliance
 
- No secrets, credentials, or tokens are included
- No customer data is collected or sent externally
- No write, update, or delete operations are performed
- The script requires explicit user consent before execution
 
---
 
## License
 
This project is licensed under the MIT License.

## Trademark

This project may contain trademarks or logos for projects, products, or services. Authorized use of Microsoft trademarks or logos is subject to and must follow Microsoft’s Trademark & Brand Guidelines. Use of Microsoft trademarks or logos in modified versions of this project must not cause confusion or imply Microsoft sponsorship. Any use of third-party trademarks or logos is subject to the applicable third-party policies.
