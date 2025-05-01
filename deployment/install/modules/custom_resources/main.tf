resource "kubernetes_manifest" "app_project" {
    manifest = provider::kubernetes::manifest_decode(file("${path.module}/../../../argocd/project/chorus-build.yaml"))
}

resource "kubernetes_manifest" "application_set" {
    manifest = provider::kubernetes::manifest_decode(file("${path.module}/../../../argocd/applicationset/applicationset-chorus-build.yaml"))
}