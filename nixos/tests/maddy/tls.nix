import ../make-test-python.nix (
  { pkgs, ... }:
  let
    certs = import ../common/acme/server/snakeoil-certs.nix;
    domain = certs.domain;
  in
  {
    name = "maddy-tls";
    meta = with pkgs.lib.maintainers; {
      maintainers = [ onny ];
    };

    nodes = {
      server =
        { options, ... }:
        {
          services.maddy = {
            enable = true;
            hostname = domain;
            primaryDomain = domain;
            openFirewall = true;
            ensureAccounts = [ "postmaster@${domain}" ];
            tls = {
              loader = "file";
              certificates = [
                {
                  certPath = "${certs.${domain}.cert}";
                  keyPath = "${certs.${domain}.key}";
                }
              ];
            };
            config =
              ''
                debug true

                auth.plain_separate send_authdb {
                  pass &recv_authdb
                }

                storage.imapsql local_mailboxes {
                  driver sqlite3
                  dsn imapsql.db
                }

                msgpipeline local_routing {
                  destination $(local_domains) {
                    # https://maddy.email/tutorials/alias-to-remote/
                    # vvvvv   This reroute makes it crash    vvvvv
                    reroute {
                        #destination $(local_domains) {
                        #    deliver_to &local_mailboxes
                        #}
                        default_destination {
                          reject 501 5.1.8 "Dummy server"
                        }
                    }
                    # ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
                  }
                  default_destination {
                    reject 550 5.1.1 "User doesn't exist"
                  }
                }

                submission tls://0.0.0.0:465 tcp://0.0.0.0:587 {
                  auth &send_authdb
                  source $(local_domains) {
                    destination $(local_domains) {
                      deliver_to &local_routing
                    }

                    default_destination {
                      reject 501 5.1.8 "Dummy server"
                    }
                  }
                  default_source {
                    reject 501 5.1.8 "Non-local sender domain"
                  }
                }

                imap tls://0.0.0.0:993 tcp://0.0.0.0:143 {
                  auth &recv_authdb
                  storage &local_mailboxes
                }

                # Passwords hashed with `maddyctl hash`
                auth.pass_table recv_authdb {
                  table static {
                    # test
                    entry postmaster@${domain} bcrypt:$2a$10$tAgW/aaD2KDyMY07MqiFdOfkeBDIZI3.AIHfQTMJDs5t4qdIS6UTW
                  }
                }
              '';
          };
          # Not covered by openFirewall yet
          networking.firewall.allowedTCPPorts = [
            993
            465
          ];
        };

      client =
        { nodes, ... }:
        {
          security.pki.certificateFiles = [
            certs.ca.cert
          ];
          networking.extraHosts = ''
            ${nodes.server.networking.primaryIPAddress} ${domain}
          '';
          environment.systemPackages = [
            (pkgs.writers.writePython3Bin "send-testmail" { } ''
              import smtplib
              import ssl
              from email.mime.text import MIMEText

              context = ssl.create_default_context()
              msg = MIMEText("Hello World")
              msg['Subject'] = 'Test'
              msg['From'] = "postmaster@${domain}"
              msg['To'] = "postmaster@${domain}"
              with smtplib.SMTP_SSL(host='${domain}', port=465, context=context) as smtp:
                  smtp.login('postmaster@${domain}', 'test')
                  smtp.sendmail(
                    'postmaster@${domain}', 'postmaster@${domain}', msg.as_string()
                  )
            '')
            (pkgs.writers.writePython3Bin "test-imap" { } ''
              import imaplib

              with imaplib.IMAP4_SSL('${domain}') as imap:
                  imap.login('postmaster@${domain}', 'test')
                  imap.select()
                  status, refs = imap.search(None, 'ALL')
                  assert status == 'OK'
                  assert len(refs) == 1
                  status, msg = imap.fetch(refs[0], 'BODY[TEXT]')
                  assert status == 'OK'
                  assert msg[0][1].strip() == b"Hello World"
            '')
          ];
        };
    };

    testScript = ''
      start_all()
      server.wait_for_unit("maddy.service")
      server.wait_for_open_port(143)
      server.wait_for_open_port(993)
      server.wait_for_open_port(587)
      server.wait_for_open_port(465)
      client.succeed("send-testmail")
      client.succeed("test-imap")
    '';
  }
)
