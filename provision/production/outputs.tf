output "load_balancer_ip" {
  value = kubernetes_service.nginx-example.load_balancer_ingress[0].ip
}
