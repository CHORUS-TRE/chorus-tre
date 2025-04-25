# Contributing Guide

This guide outlines the manual steps for contributing changes. This is useful for testing changes on the dev environment.

## Prerequisites

*   Access to the relevant Git repositories (Chorus-TRE and environment repositories with ability to create branches).
*   Helm CLI installed.
*   kubectl CLI installed and configured to access the target Kubernetes cluster (e.g., `dev`, `qa`).
*   Access to the ArgoCD UI or CLI for the target environment.
*   Familiarity with Git, GitHub Pull Requests, and Helm concepts.

## Contribution Workflow

1.  **Develop and Create a Pull Request (PR):**
    *   Create a new branch for your feature or fix (or take one of the renovate branches you want to merge).
    *   Make your changes in the application code repository (e.g., `chorus-tre`).
    *   Push your branch and create a Pull Request against the main branch. Mark it as a "Draft" if it's work-in-progress.

2.  **Update Chart Version in PR:**
    *   Manually edit the relevant `Chart.yaml` file within your PR branch to increment the chart version. Commit and push this change to your PR branch. This is very easy to do via the Github interface and fits well in the workflow so we recommend doing it this way.

3.  **Prepare Local Environment:**
    *   Ensure your local Git repository clone is up-to-date:
        ```bash
        git checkout main # Or your target base branch
        git pull origin main
        git checkout your-feature-branch
        git pull origin your-feature-branch # Ensure local branch has version bump
        ```

4.  **Disable ArgoCD Self-Heal (Temporary):**
    *   Navigate to the ArgoCD UI for the target environment (e.g., `dev`).
    *   Locate the Application corresponding to the chart you are updating.
    *   Temporarily disable the "self-heal" feature for this Application. This prevents ArgoCD from immediately reverting your manual changes during testing. *Refer to ArgoCD documentation or internal guides for the exact steps.*
    Note: this could also be done using the Argo CLI

5.  **Verify Changes with Helm Template and Diff:**
    *   Run the following command to generate the Kubernetes manifests based on your local chart changes and compare them against the live state in the cluster. **Carefully review the output for unintended and / or incompatible changes.** Pay attention to resource configurations, image tags, environment variables, and any removed or added resources to ensure only your intended modifications are present.
    *   Replace placeholders (`$env`, `$chart_env`, `$chart`, `$namespace`, `$k8s_version`, `$chorus`) with actual values for your environment. The `$chorus` variable should point to the root of your local `chorus-tre` repository clone.
        ```bash
        helm template chorus-$env-$chart_env $chorus/chorus-tre/charts/$chart -n $namespace --kube-version $k8s_version --values $chorus/environments/chorus-$env/$chart_env/values.yaml | kubectl diff -f -
        ```
    *   *(Optional: Use `| less` at the end if the diff is large, or pipe it to open in VSCode via `| code -`, or pipe it to open in Cursor via `| cursor -`)*

6.  **Deploy Changes Manually for Testing:**
    *   If the diff looks correct, apply the changes to the cluster using Helm template and kubectl apply. **This step bypasses ArgoCD's sync mechanism for immediate testing.**
    *   Replace placeholders as in the previous step.
    *   **(Method 1: Apply directly - Recommended)**
        ```bash
        helm template chorus-$env-$chart_env $chorus/chorus-tre/charts/$chart -n $namespace --kube-version $k8s_version --skip-tests --values $chorus/environments/chorus-$env/$chart_env/values.yaml | kubectl apply -f -
        ```
    *   **(Method 2: Save to file then apply)**
        ```bash
        helm template chorus-$env-$chart_env $chorus/chorus-tre/charts/$chart -n $namespace --kube-version $k8s_version --skip-tests --values $chorus/environments/chorus-$env/$chart_env/values.yaml > /tmp/values-new.yaml
        kubectl apply -f /tmp/values-new.yaml
        ```

7.  **Test Your Changes:**
    *   Make sure that after the deployment everything is healthy in ArgoCD (no crashloop backoff, etc...)
    *   Thoroughly test your feature or fix in the target environment.

8.  **Post-Testing Steps:**

    *   **If Testing Failed or Needs More Work:**
        *   If testing fails, the simplest way to revert is usually to re-enable ArgoCD self-heal for the Application. ArgoCD will then sync the application back to the state defined in the environment repository.
        *   Continue development on your branch.

    *   **If Testing Succeeded:**
        *   **Do not re-enable self-heal yet.**
        *   Seek approval for your Pull Request in the application code repository.
        *   Once approved, squash and merge your PR into the main branch.

9.  **Update Environment Repository:**
    *   After the application PR is merged, an automated process (or manual step, if automation fails) should create a Merge Request (MR) in the Chorus environment repository. This MR updates the chart version used by ArgoCD for the `dev` environment. You will also find one opened for QA.
    *   Approve and merge this MR in the environments repository (https://github.com/CHORUS-TRE/environments). This triggers ArgoCD to deploy the officially merged version to `dev` and Argo will be in the correct state.

10. **Re-enable ArgoCD Self-Heal:**
    *   Once the environment MR is merged and ArgoCD has successfully synced the new version from the main branch, you can now safely re-enable the "self-heal" feature for the Application in the ArgoCD UI for `dev`. Since the version deployed matches the one you manually bumped in the PR (which is now merged), ArgoCD should not revert anything.

11. **Promote to QA (IF APPLICABLE !):**
    *   Follow a similar process (typically via environment repository MRs) to promote the change to the `qa` environment after successful validation in `dev`.

## Testing Local-Only Changes

Sometimes you may need to test changes that involve sensitive data (like API keys or credentials), which **must not** be committed to any Git repository or included in a Pull Request (or you just don't want to show bad code just yet). Follow this modified procedure:

1.  **Modify Code/Configuration Locally:** Make the necessary changes directly in your local checkout of the repository (e.g., `chorus-tre`). **Do NOT commit these changes using Git.**
2.  **Disable ArgoCD Self-Heal:** Follow Step 4 from the main workflow.
3.  **Verify with Diff:** You can still use `helm template ... | kubectl diff -f -` (Step 5) to preview the changes *before* applying them, ensuring the secret is being injected as expected and no other unintended changes occur.
4.  **Deploy Manually for Testing:** Use `helm template ... | kubectl apply -f -` (Step 6) using your **local, uncommitted** files containing the secrets.
5.  **Test Your Changes:** Perform your tests (Step 7).
6.  **Manually Revert Changes:** **Crucially**, *before* proceeding, manually revert the specific changes you applied, especially those involving secrets. This might involve:
    *   Running `kubectl delete` on the specific resources you created/modified.
    *   Running `helm template ... | kubectl apply -f -` again but using the *original* configuration files (without your local secret modifications).
    *   **Warning:** Be aware that `kubectl apply` stores the applied configuration, including any secrets you added locally, in the `kubectl.kubernetes.io/last-applied-configuration` annotation of the resource. This annotation can be viewed using `kubectl get <resource-type> <resource-name> -o yaml`. To remove potentially exposed secrets from this annotation after testing, ensure your final revert action (e.g., re-applying the original configuration) overwrites this annotation with a clean version. Avoid applying manifests with hardcoded secrets whenever possible, even during testing. If you have done so, rotate these secrets.
7.  **Re-enable ArgoCD Self-Heal:** Once you are certain the sensitive changes have been manually reversed, you can re-enable ArgoCD self-heal (Step 10). ArgoCD will then ensure the state matches the configuration in the environment repository.
8.  **Discard Local Changes:** Use `git stash` or `git checkout -- .` carefully in your local repository to discard the uncommitted changes containing secrets.

**IMPORTANT:** Never commit secrets or sensitive configuration directly into the codebase or configuration files that are tracked by Git. If secrets are needed permanently, they should be managed through secure mechanisms like Kubernetes Secrets, HashiCorp Vault, or similar solutions, referenced by the Helm chart, not hardcoded.

## Important Notes

*   Replace placeholder variables like `$env`, `$chart_env`, `$chart`, `$namespace`, `$k8s_version`, and `$chorus` (path to local repo clone) with the correct values for your context. You can typically find values for `$env`, `$chart_env`, and `$chart` by examining the directory structure and `values.yaml` files within the `environments/` directory. `$namespace` and `$k8s_version` depend on your target cluster configuration.
*   Disabling self-heal should be done cautiously and only for the duration of manual testing. Ensure it is re-enabled promptly after the process is complete.
*   The `kubectl diff` step is crucial for preventing accidental breaking changes. Review its output carefully.
