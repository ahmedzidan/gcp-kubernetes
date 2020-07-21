output "public_ip" {
  value = kubernetes_ingress.app_ingress.load_balancer_ingress
}
