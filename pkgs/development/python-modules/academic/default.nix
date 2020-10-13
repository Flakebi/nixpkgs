{ lib
, buildPythonApplication
, fetchPypi
, bibtexparser
, requests
, ruamel_yaml
, toml
}:

buildPythonApplication rec {
  pname = "academic";
  version = "0.7.0";

  src = fetchPypi {
    inherit pname version;
    sha256 = "/g0JPT/+rGNGTShOMoswYdECIqZcSoC4mWUGO6u3kP4=";
  };

  propagatedBuildInputs = [ bibtexparser requests ruamel_yaml toml ];

  checkInputs = [ ];

  meta = with lib; {
    description = "Import publications from your reference manager to Hugo";
    homepage = "https://github.com/wowchemy/hugo-academic-cli";
    license = licenses.mit;
    maintainers = with lib.maintainers; [ Flakebi ];
  };
}
