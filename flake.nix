{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };

          picoclaw = pkgs.buildGoModule rec {
            pname = "picoclaw";
            version = "0.2.6";

            src = pkgs.fetchFromGitHub {
              owner = "sipeed";
              repo = "picoclaw";
              rev = "v${version}";
              hash = "sha256-ohqnfBn3CbBrR+ynOVtBsBBCgP7pP2HHzYElbw1Ygf8=";
            };

            vendorHash = "sha256-vUJBeB2FiV1frc+CW3Q7Lxkfon9oaV/7QPDTMRu7NrY=";
            proxyVendor = true;

            env.CGO_ENABLED = "0";

            tags = [
              "goolm"
              "stdjson"
            ];

            subPackages = [ "cmd/picoclaw" ];

            preBuild = ''
              go generate ./cmd/picoclaw/...
            '';

            ldflags = [
              "-s"
              "-w"
              "-X github.com/sipeed/picoclaw/pkg/config.Version=${version}"
            ];
          };
        in
        {
          inherit picoclaw;
          default = picoclaw;
        }
        // nixpkgs.lib.optionalAttrs pkgs.stdenv.isLinux {
          docker = pkgs.dockerTools.buildImage {
            name = "picoclaw-copilot";
            tag = "latest";

            copyToRoot = pkgs.buildEnv {
              name = "image-root";
              paths = [
                picoclaw
                pkgs.git
                pkgs.openssh
                pkgs.gh
                pkgs.copilot-cli
                pkgs.cacert
                pkgs.bashInteractive
                pkgs.coreutils
                pkgs.tzdata
                pkgs.dockerTools.fakeNss
              ];
            };

            extraCommands = ''
              mkdir -p root tmp
              chmod 1777 tmp
            '';

            config = {
              Entrypoint = [ "picoclaw" ];
              Env = [
                "HOME=/root"
                "TMPDIR=/tmp"
                "SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt"
                "TZDIR=/share/zoneinfo"
              ];
            };
          };
        }
      );
    };
}
