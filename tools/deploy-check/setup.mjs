// What bootstrap.sh prints into tofu/ci.env, read by more than one tool: the deployment's target
// (tools/deploy/target.mjs), which runs in steps of the workflow Deploy that install no package, and
// the pull request's check of the list (check.mjs). So this file imports nothing (R13, R14).

// The provider of the federated pool, as GCP_WORKLOAD_IDENTITY_PROVIDER names it: the project is
// named by its number, the pattern's one group, which is how api's service's address names it too
// (the output api_origin; R05).
export const PROVIDER = /^projects\/([0-9]+)\/locations\/global\/workloadIdentityPools\/[a-z0-9-]+\/providers\/[a-z0-9-]+$/;
