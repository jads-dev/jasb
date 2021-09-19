variable "HOST" { default = "ghcr.io" }
variable "REPO" { default = "jads-dev/jasb" }
variable "HASH" { default = "dev" }

target "build" {
  dockerfile = "./Dockerfile"
  platforms = ["linux/amd64", "linux/arm64"]
  output = ["type=registry"]
  pull = true
}

target "server" {
  context = "./server"
  inherits = ["build"]
  tags = [
    lower("${HOST}/${REPO}/server:${HASH}"),
    lower("${HOST}/${REPO}/server:latest")
  ]
}

target "client" {
  context = "./client"
  inherits = ["build"]
  tags = [
    lower("${HOST}/${REPO}/client:${HASH}"),
    lower("${HOST}/${REPO}/client:latest")
  ]
}

group "default" {
  targets = [ "server", "client" ]
}
