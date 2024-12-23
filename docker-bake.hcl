# The name of the version, must be semver compliant, used to generate semantically versioned tags and passed to the build.
variable "VERSION" {
  default = ""
}

# The version control reference (commit hash). This is used as a specific-build tag and a fallback version.
variable "VCS_REF" {
  default = "unknown"
}

# The moment at which the build was done.
variable "BUILD_DATE" {
  default = timestamp()
}

# If the build should be a production or development build.
variable "MODE" {
  default = "production"
}

# The public URL the build expects to exist under.
variable "URL" {
  default = "https://bets.jads.stream/"
}

# The repo to tag the images with.
variable "REPO" {
  default = "ghcr.io/jads-dev/jasb/"
}

function "splitSemVer" {
  params = [version]
  result = regexall("^v?(?P<major>0|[1-9]\\d*)\\.(?P<minor>0|[1-9]\\d*)\\.(?P<patch>0|[1-9]\\d*)(?:-(?P<prerelease>(?:0|[1-9]\\d*|\\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\\.(?:0|[1-9]\\d*|\\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?(?:\\+(?P<buildmetadata>[0-9a-zA-Z-]+(?:\\.[0-9a-zA-Z-]+)*))?$", version)
}

function "generateVersionTags" {
  params = [semVer]
  result = length(semVer) != 1 ? [] : concat(
    semVer[0]["prerelease"] != null ?
      ["${semVer[0]["major"]}.${semVer[0]["minor"]}.${semVer[0]["patch"]}-${semVer[0]["prerelease"]}"] :
      [
        "${semVer[0]["major"]}.${semVer[0]["minor"]}.${semVer[0]["patch"]}",
        "${semVer[0]["major"]}.${semVer[0]["minor"]}",
        "${semVer[0]["major"]}",
        "latest-release",
      ],
    ["latest-prerelease"]
  )
}

function "generateTags" {
  params = [component]
  result = flatten([
    for tag in flatten(
      ["${VCS_REF}-dev", generateVersionTags(splitSemVer(VERSION)),
      "latest"]
    ) : "${REPO}${component}:${tag}"
  ])
}

# Shared build arguments.
target "args" {
  args = {
    VERSION = VERSION != "" ? VERSION : "${VCS_REF}-dev"
    VCS_REF = VCS_REF
    BUILD_DATE = BUILD_DATE
    MODE = MODE
    URL = URL
    NGINX_BASE = "nginx"
  }
}

target "nginx" {
  platforms = ["linux/amd64", "linux/arm64"]
  context = "./client/nginx"
  pull = true
  output = ["type=docker"]
  args = {
    ENABLED_MODULES = "brotli"
  }
}

# Build into container images.
target "images" {
  name = component
  inherits = ["args"]
  platforms = ["linux/amd64", "linux/arm64"]
  matrix = {
    component = ["server", "client", "migrate"]
  }
  context = "./${component}"
  contexts = {
    nginx = "docker-image://nginx:mainline-alpine" #"target:nginx"
  }
  pull = true
  output = ["type=docker"]
  tags = generateTags(component)
}

# Build into source files in the dist directory.
target "sources" {
  name = "${component}-sources"
  inherits = ["args"]
  matrix = {
    component = ["server", "client", "migrate"]
  }
  context = "./${component}"
  pull = true
  target = "sources"
  output = ["type=local,dest=dist/${component}"]
}

group "default" {
  targets = [ "images" ]
}
