output "public_url" {
  description = "Exposed HTTP URL"
  value = "http://${local.public_dns}/"
}
