variable "HOST" { default = "ghcr.io" }
variable "REPO" { default = "jads-dev/jasb" }
variable "HASH" { default = "dev" }
variable "BUILD_DATE" { default = "" }

target "build" {
  dockerfile = "./Dockerfile"
  platforms = ["linux/amd64", "linux/arm64"]
  output = ["type=registry"]
  pull = true
  args = {
    VCS_REF = HASH
    BUILD_DATE = BUILD_DATE
  }
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
