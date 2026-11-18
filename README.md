# infra

[![CI](https://github.com/altnovatrail/infra/actions/workflows/ci.yml/badge.svg)](https://github.com/altnovatrail/infra/actions/workflows/ci.yml)
[![CodeQL](https://github.com/altnovatrail/infra/actions/workflows/codeql.yml/badge.svg)](https://github.com/altnovatrail/infra/actions/workflows/codeql.yml)
[![OpenSSF Scorecard](https://api.scorecard.dev/projects/github.com/altnovatrail/infra/badge)](https://scorecard.dev/viewer/?uri=github.com/altnovatrail/infra)
[![License](https://img.shields.io/github/license/altnovatrail/infra)](LICENSE)

[![Code Smells](https://sonarcloud.io/api/project_badges/measure?project=altnovatrail_infra&metric=code_smells)](https://sonarcloud.io/summary/new_code?id=altnovatrail_infra)
[![Reliability Rating](https://sonarcloud.io/api/project_badges/measure?project=altnovatrail_infra&metric=reliability_rating)](https://sonarcloud.io/summary/new_code?id=altnovatrail_infra)
[![Security Rating](https://sonarcloud.io/api/project_badges/measure?project=altnovatrail_infra&metric=security_rating)](https://sonarcloud.io/summary/new_code?id=altnovatrail_infra)
[![Maintainability Rating](https://sonarcloud.io/api/project_badges/measure?project=altnovatrail_infra&metric=sqale_rating)](https://sonarcloud.io/summary/new_code?id=altnovatrail_infra)
[![Vulnerabilities](https://sonarcloud.io/api/project_badges/measure?project=altnovatrail_infra&metric=vulnerabilities)](https://sonarcloud.io/summary/new_code?id=altnovatrail_infra)

The shared infrastructure of NovaTrail: the cloud projects, the identities that let CI deploy, the image registry, the secrets, the budgets, the domains, the logs and the hosting of the app's build, and the way to run the whole platform yourself, on your own servers or on one machine. It deploys the platform's services and the app's build by one list of exact versions and digests, building each service's image from the signed files of its release, and self-hosting takes the same list. It holds no learner's data and no code of the platform's services.

A component of [NovaTrail](https://github.com/altnovatrail/spec), a universal open platform for adaptive learning, interactive lessons and AI tutoring.

Nothing calls it while the platform runs, and it calls nothing: it deploys the releases of `api`, the platform's server, which alone of its parts stores learners' data, and of `app`, the web app of learners and adults, and it lays the cloud they run on — the services, the image registry, the secrets, the hosting and the logs —, while `api` chooses its own database and sign-in service.

Its card is architecture 3.11 spec, among the documents of [spec](https://github.com/altnovatrail/spec); its own documents, its decisions and its plan, with the guide to a self-hosted copy and the procedure for a breach of learners' data, are in [docs/](docs/README.md).
