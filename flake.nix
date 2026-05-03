{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    llm-agents.url = "github:numtide/llm-agents.nix";
  };

  outputs =
    { self, nixpkgs, llm-agents }:
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
          copilot-cli = llm-agents.packages.${system}.copilot-cli;

          picoclaw = pkgs.buildGoModule rec {
            pname = "picoclaw";
            version = "0.2.8";

            src = pkgs.fetchFromGitHub {
              owner = "sipeed";
              repo = "picoclaw";
              rev = "v${version}";
              hash = "sha256-PCPqdxXoXgJZduw3o5p6+heQ8wHxidcqGQBxqD3IdjQ=";
            };

            patches = [
              ./patches/0001-add-slash-commands.patch
              ./patches/0002-add-opencode-tool.patch
              ./patches/0003-add-multi-channel-session-history.patch
              ./patches/0004-add-subagent-discord-visibility.patch
              ./patches/0005-fix-copilot-session-resume.patch
            ];

            vendorHash = "sha256-LVfn2PsgqRVF/mLN/TLAENDEo+MnFc4DVG13+6dU+V4=";
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
                copilot-cli
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
