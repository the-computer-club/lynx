{ lib, buildPythonApplication, requests }:
buildPythonApplication {
  src = lib.cleanSource ./.;
  pname = "wg-names";
  version = "0.1.0";
  propagatedBuildInputs = [ requests ];
}
