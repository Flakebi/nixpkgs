{ lib, buildGoModule, fetchFromGitHub, coreutils }:

buildGoModule rec {
  pname = "haproxy-spoe-auth";
  version = "unstable-2021-02-15";

  src = fetchFromGitHub {
    owner = "criteo";
    repo = pname;
    rev = "d4abff4d3d37c5097de85913c576e98ad7d1ef4f";
    sha256 = "8k07hOD5KezmW7R4HxJaGD46DpoWVQgKDOKkM1QxjyE=";
  };

  vendorSha256 = "UByhFhSPSd1hEA3Q+D/YG67DSUOUGC49JgzoZDd8aGg=";

  # Needs network and other servers running
  doCheck = false;

  meta = with lib; {
    homepage = "https://github.com/criteo/haproxy-spoe-auth";
    description = "HAProxy plugin for authorizing users";
    license = licenses.asl20;
    maintainers = with maintainers; [ Flakebi ];
  };
}
