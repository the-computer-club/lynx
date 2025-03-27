{ lib, buildPythonApplication, requests }:
buildPythonApplication {
  src = lib.cleanSource ./.;
  pname = "wg-names";
  version = "0.0.1";
  propagatedBuildInputs = [ requests ];
}
