# Get information about the EKS cluster
data "aws_eks_cluster" "primary" {
  name = "rigetti-demo"
}

# Get authentication token for the EKS cluster
data "aws_eks_cluster_auth" "primary" {
  name = "rigetti-demo"
}

# Get current AWS region (similar to google_client_config)
data "aws_region" "current" {}

resource "kubernetes_namespace" "nginx_ingress" {
  metadata {
    name = "nginx-ingress"
  }

}


resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
  }
  depends_on = [
    helm_release.nginx_ingress
  ]
}

resource "kubernetes_namespace" "cert_manager" {
  metadata {
    name = "cert-manager"
  }
}

resource "helm_release" "nginx_ingress" {
  name       = "nginx-ingress"
  namespace  = kubernetes_namespace.nginx_ingress.metadata[0].name
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = "4.10.0"

  set {
    name  = "controller.publishService.enabled"
    value = "true"
  }

  set {
    name  = "controller.allowSnippetAnnotations"
    value = "true"
  }

  set {
    name  = "controller.ingressClassResource.default"
    value = "true"
  }

  set {
    name  = "controller.ingressClassResource.name"
    value = "nginx"
  }

  set {
    name  = "controller.ingressClassResource.enabled"
    value = "true"
  }

  # Add ModSecurity configuration
  set {
    name  = "controller.config.enable-modsecurity"
    value = "true"
  }

  set {
    name  = "controller.config.enable-owasp-modsecurity-crs"
    value = "true"
  }

  depends_on = [kubernetes_namespace.nginx_ingress]
}

resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  namespace  = kubernetes_namespace.cert_manager.metadata[0].name
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  version    = "v1.14.4"

  set {
    name  = "installCRDs"
    value = "true"
  }

  timeout = 600

  depends_on = [kubernetes_namespace.cert_manager]
}

resource "helm_release" "promtail" {
  name       = "promtail"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  repository = "https://grafana.github.io/helm-charts"
  chart      = "promtail"
  version    = "6.16.2"  # Corrected the version format, should be without 'v'

  values = [
    <<-EOF
    config:
      clients:
        - url: http://loki-gateway/loki/api/v1/push
          tenant_id: "1"  # tenant_id should be a string if using multi-tenancy
    EOF
  ]

  timeout = 600

  depends_on = [kubernetes_namespace.monitoring]
}

#resource "helm_release" "loki" {
#  name       = "loki"
#  namespace  = kubernetes_namespace.monitoring.metadata[0].name
#  repository = "https://grafana.github.io/helm-charts"
#  chart      = "loki"
#  version    = "6.6.5"

#    set_sensitive {
#    name  = "loki.storage.s3.accessKeyId"
#    value = var.aws_access_key
#  }

#  set_sensitive {
#    name  = "loki.storage.s3.secretAccessKey"
#    value = var.aws_secret_key
#  }

#  values = [
#    <<-EOF
#    loki:
#      storage:
#        bucketNames:
#          chunks: loki-chunks-demo-bucket
#          ruler: loki-ruler-bucket-demo
#          admin: loki-admin-bucket-demo
#        type: s3
#        s3:
#          s3: s3://loki-demo-bucket-logs
#          endpoint: ""
#          region: us-east-1
#          s3ForcePathStyle: false
#          insecure: false
#      useTestSchema: false
#      testSchemaConfig: {}
#      schemaConfig:
#        configs:
#          - from: 2024-04-01
#            store: tsdb
#            object_store: aws
#            schema: v13
#            index:
#              prefix: loki_index_
#              period: 24h
#      auth_enabled: false
#    EOF
#  ]
  
#  timeout = 1200

#  depends_on = [kubernetes_namespace.monitoring]
#}

 
resource "helm_release" "kube-prometheus-stack" {
  name       = "kube-prometheus-stack"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = "48.1.1"

    set_sensitive {
    name  = "alertmanager.config.receivers[0].s3_configs[0].access_key"
    value = var.aws_access_key
  }

  set_sensitive {
    name  = "alertmanager.config.receivers[0].s3_configs[0].secret_key"
    value = var.aws_secret_key
  }

  values = [
    <<-EOF
    alertmanager:
      config:
        global:
          resolve_timeout: 5m
        inhibit_rules:
          - source_matchers:
              - 'severity = critical'
            target_matchers:
              - 'severity =~ warning|info'
            equal:
              - 'namespace'
              - 'alertname'
          - source_matchers:
              - 'severity = warning'
            target_matchers:
              - 'severity = info'
            equal:
              - 'namespace'
              - 'alertname'
          - source_matchers:
              - 'alertname = InfoInhibitor'
            target_matchers:
              - 'severity = info'
            equal:
              - 'namespace'
        route:
          receiver: sns-alerts
          group_by: ["alertname"]
          group_wait: 30s
          group_interval: 5m
          repeat_interval: 24h
          routes:
            - match:
                alertname: InfoInhibitor
              receiver: 'null'
            - match:
                alertname: "KubeControllerManagerDown"
              receiver: 'null'
            - match:
                alertname: "KubeAggregatedAPIErrors"
              receiver: 'null'
            - match:
                alertname: "KubeProxyDown"
              receiver: 'null'
            - match:
                alertname: "KubeSchedulerDown"
              receiver: 'null'
            - match_re:
                job: "coredns"
              receiver: 'null'
            - match_re:
                severity: 'critical|warning'
              receiver: sns-alerts
        receivers:
          - name: 'null'
          - name: "sns-alerts"
            sns_configs:
            - topic_arn: "arn:aws:sns:us-east-1:985883769551:rigettidemo"
              api_url: https://sns.us-east-1.amazonaws.com
              sigv4:
                region: "us-east-1"
              subject: "rigetti-demo-cluster-[{{ .Status | toUpper }}] {{ .GroupLabels.alertname }} - {{ .GroupLabels.severity }}"
        templates:
          - '/etc/alertmanager/config/*.tmpl'
      ingress:
        enabled: true
        ingressClassName: nginx
        annotations:
          kubernetes.io/tls-acme: "false"
          cert-manager.io/cluster-issuer: "letsencrypt-prod"
        labels: {}
        hosts:
          - alertmanager.rigettidemo.com
        paths:
          - /
        pathType: Prefix
        tls:
          - secretName: alertmanager-tls
            hosts:
              - alertmanager.rigettidemo.com
    grafana:
      enabled: true
      persistence:
        enabled: true
        type: pvc
        accessModes:
          - ReadWriteOnce
        size: "2Gi"
        finalizers:
          - kubernetes.io/pvc-protection
      ingress:
        enabled: true
        ingressClassName: nginx
        annotations:
          kubernetes.io/tls-acme: "false"
          cert-manager.io/cluster-issuer: "letsencrypt-prod"
        labels: {}
        hosts:
          - monitoring.rigettidemo.com
        path: /
        tls: 
          - secretName: grafana-tls
            hosts:
              - monitoring.rigettidemo.com
    EOF
  ]

  timeout = 1200

  depends_on = [
    kubernetes_namespace.monitoring
  ]
}

resource "null_resource" "delay" {
  provisioner "local-exec" {
    command = "sleep 60"  # Sleep for 60seconds (1 minute)
  }
}

resource "helm_release" "aws_ebs_csi_driver" {
  name       = "aws-ebs-csi-driver"
  repository = "https://kubernetes-sigs.github.io/aws-ebs-csi-driver"
  chart      = "aws-ebs-csi-driver"
  version    = "2.43.0"
  namespace  = "kube-system"

  set {
    name  = "storageClasses[0].name"
    value = "ebs-sc"
  }

  set {
    name  = "storageClasses[0].volumeBindingMode"
    value = "Immediate"
  }

  set {
    name  = "storageClasses[0].parameters.type"
    value = "gp2"
  }


}

#Kubernetes ClusterIssuer configuration for cert-manager
resource "kubernetes_manifest" "cluster_issuer" {
  depends_on = [null_resource.delay]
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "letsencrypt-prod"
    }
    spec = {
      acme = {
        email              = "kollzey539@gmail.com"
        preferredChain     = ""
        privateKeySecretRef = {
          name = "letsencrypt-secret-prod"
        }
        server = "https://acme-v02.api.letsencrypt.org/directory"
        solvers = [{
          http01 = {
            ingress = {
              class = "nginx"
            }
          }
        }]
      }
    }
  }
}


# Create the observability namespace
resource "kubernetes_namespace" "observability" {
  metadata {
    name = "observability"
  }
}

#resource "helm_release" "opentelemetry_operator" {
#  name       = "opentelemetry-operator"
#  namespace  = kubernetes_namespace.observability.metadata[0].name
#  repository = "https://open-telemetry.github.io/opentelemetry-helm-charts"
#  chart      = "opentelemetry-operator"
#  version    = "0.68.1"

#  depends_on = [kubernetes_namespace.observability]

#  values = [
#    <<-EOF
#      manager:
#        collectorImage:
#          repository: "otel/opentelemetry-collector-k8s"
#      admissionWebhooks:
#        certManager:
#          enabled: false
#        autoGenerateCert:
#          enabled: true
#    EOF
#  ]
#}









#resource "helm_release" "jaeger_operator" {
#  name       = "jaeger-operator"
#  namespace  = "observability"
#  repository = "https://jaegertracing.github.io/helm-charts"
#  chart      = "jaeger-operator"
#  version    = "2.56.0"

#  depends_on = [kubernetes_namespace.observability]

#  values = [
#    <<-EOF
#      certs:
#        issuer:
#          create: true
#        certificate:
#          create: true
#      jaeger:
#        create: true
#        namespace: "observability"
#        spec:
#          strategy: production
#          storage:
#            type: elasticsearch
#            options:
#              es:
#                server-urls: http://elasticsearch-service:9200
#          ingress:
#            enabled: true
#            ingressClassName: "nginx"
#      rbac:
#        create: true
#        clusterRole: true
#    EOF
#  ]
#}




#resource "kubernetes_manifest" "elasticsearch_statefulset" {
#  depends_on = [kubernetes_namespace.observability]
#  manifest = {
#    "apiVersion" : "apps/v1",
#    "kind" : "StatefulSet",
#    "metadata" : {
#      "name" : "elasticsearch-statefulset",
#      "namespace" : "observability"
#    },
#    "spec" : {
#      "replicas" : 1,
#      "serviceName" : "elasticsearch-service",
#     "selector" : {
#        "matchLabels" : {
#          "component" : "elasticsearch"
#        }
#      },
#      "template" : {
#        "metadata" : {
#          "labels" : {
#            "component" : "elasticsearch"
#          }
#        },
#        "spec" : {
#         "containers" : [{
#            "name" : "elasticsearch",
#            "image" : "docker.elastic.co/elasticsearch/elasticsearch:7.17.1",
#            "ports" : [{
#              "containerPort" : 9200,
#              "protocol" : "TCP"
#            }],
#            "env" : [
#              {
#                "name" : "discovery.type",
#                "value" : "single-node"
#              },
#              {
#                "name" : "bootstrap.memory_lock",
#                "value" : "true"
#              },
#              {
#               "name" : "ES_JAVA_OPTS",
#                "value" : "-server -Xss1024K -Xmx2G"
#              },
#              {
#                "name" : "TAKE_FILE_OWNERSHIP",
#                "value" : "true"
#              }
#            ],
#            "volumeMounts" : [
#              {
#                "mountPath" : "/usr/share/elasticsearch/data",
#                "name" : "data"
#              },
#              {
#                "mountPath" : "/usr/share/elasticsearch/logs",
#                "name" : "logs"
#              }
#            ]
#          }],
#          "volumes" : [
#            {
#              "name" : "logs",
#              "emptyDir" : {}  # Define emptyDir explicitly
#            }
#          ]
#        }
#      },
#      "volumeClaimTemplates" : [{
#        "metadata" : {
#          "name" : "data"
#        },
#        "spec" : {
#          "accessModes" : ["ReadWriteOnce"],
#          "resources" : {
#            "requests" : {
#              "storage" : "10Gi"
#            }
#          }
#        }
#      }]
#    }
#  }
#}


# Create Elasticsearch Service
#esource "kubernetes_manifest" "elasticsearch_service" {
#  depends_on = [kubernetes_namespace.observability]
#  manifest = {
#    "apiVersion" : "v1",
#    "kind" : "Service",
#    "metadata" : {
#      "name" : "elasticsearch-service",
#      "namespace" : "observability"
#    },
#    "spec" : {
#      "type" : "ClusterIP",
#      "selector" : {
#        "component" : "elasticsearch"
#      },
#      "ports" : [{
#        "protocol" : "TCP",
#        "port" : 9200,
#        "targetPort" : 9200
#      }]
#    }
#  }
#}