{
  description = "Console-only TG WS Proxy";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        python = pkgs.python312;
        pythonPackages = pkgs.python312Packages;

        tg-ws-proxy = pythonPackages.buildPythonApplication {
          pname = "tg-ws-proxy";
          version = "1.6.2";
          pyproject = true;
          src = self;

          nativeBuildInputs = [
            pythonPackages.hatchling
          ];

          propagatedBuildInputs = [
            pythonPackages.cryptography
          ];

          pythonImportsCheck = [
            "proxy"
          ];

          meta = with pkgs.lib; {
            description = "Telegram MTProto WebSocket bridge proxy";
            homepage = "https://github.com/Flowseal/tg-ws-proxy";
            license = licenses.mit;
            mainProgram = "tg-ws-proxy";
            platforms = platforms.linux ++ platforms.darwin;
          };
        };
      in {
        packages = {
          inherit tg-ws-proxy;
          default = tg-ws-proxy;
        };

        apps = {
          tg-ws-proxy = flake-utils.lib.mkApp {
            drv = tg-ws-proxy;
          };
          default = self.apps.${system}.tg-ws-proxy;
        };

        devShells.default = pkgs.mkShell {
          packages = [
            python
            pythonPackages.hatchling
            pythonPackages.build
          ];
        };
      });
}
