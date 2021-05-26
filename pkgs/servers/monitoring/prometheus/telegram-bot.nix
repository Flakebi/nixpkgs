{ lib, buildGoModule, fetchFromGitHub }:

buildGoModule rec {
  pname = "prometheus-telegram-bot";
  version = "unstable-2021-04-30";

  src = fetchFromGitHub {
    owner = "inCaller";
    repo = "prometheus_bot";
    rev = "ac4533fa7789483d2e47a7c7d931764f5cbf1c33";
    sha256 = "gvF52Q+0jm8gl9y0LGvnSrMQuCIj2YWXETt0v3Ji29Y=";
  };

  vendorSha256 = "yZ3SeAANL1gbAZ6IrTBTMmt/BIb1bDm1Svd18NkfMY8=";

  meta = with lib; {
    description = "Telegram bot for prometheus alerting";
    homepage = "https://github.com/inCaller/prometheus_bot";
    license = licenses.mit;
    maintainers = with maintainers; [ Flakebi ];
    platforms = platforms.linux;
  };
}
