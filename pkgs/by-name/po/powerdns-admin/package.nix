{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchYarnDeps,
  yarnConfigHook,
  nixosTests,
  writeText,
  python3,
  powerdns-admin,
}:

let
  pname = "powerdns-admin";
  version = "0.4.2";
  src = fetchFromGitHub {
    owner = "PowerDNS-Admin";
    repo = "PowerDNS-Admin";
    rev = "v${version}";
    hash = "sha256-q9mt8wjSNFb452Xsg+qhNOWa03KJkYVGAeCWVSzZCyk=";
  };

  python = python3;

  pythonDeps = with python.pkgs; [
    distutils
    flask
    flask-assets
    flask-login
    flask-sqlalchemy
    flask-migrate
    flask-seasurf
    flask-mail
    flask-session
    flask-session-captcha
    flask-sslify
    mysqlclient
    psycopg2
    sqlalchemy
    certifi
    cffi
    configobj
    cryptography
    bcrypt
    requests
    python-ldap
    pyotp
    qrcode
    dnspython
    gunicorn
    itsdangerous
    python3-saml
    pytz
    rcssmin
    rjsmin
    authlib
    bravado-core
    lima
    lxml
    passlib
    pyasn1
    pytimeparse
    pyyaml
    jinja2
    itsdangerous
    standard-imghdr
    webcolors
    werkzeug
    zipp
    zxcvbn
  ];

  all_patches = [
    ./0001-Fix-flask-2.3-issue.patch
  ];

  assets = stdenv.mkDerivation {
    pname = "${pname}-assets";
    inherit version src;

    offlineCache = fetchYarnDeps {
      yarnLock = "${src}/yarn.lock";
      hash = "sha256-rXIts+dgOuZQGyiSke1NIG7b4lFlR/Gfu3J6T3wP3aY=";
    };

    nativeBuildInputs = [
      yarnConfigHook
    ] ++ pythonDeps;
    patches = all_patches ++ [
      ./0002-Remove-cssrewrite-filter.patch
    ];
    buildPhase = ''
      # Fix so distutils is available in build prosess.
      # Function setuptools/_distutils/util.py:byte_compile is used in build prosess
      # but setuptools distutils import trick/hack is not working in build prosses
      # and we get ModuleNotfoundError 'No module named 'distutils'
      # For more explanation see first attempt:
      # https://github.com/NixOS/nixpkgs/pull/328182
      DISTUTILS=$(mktemp -d)
      ln -s ${python.pkgs.setuptools}/${python.sitePackages}/setuptools/_distutils "$DISTUTILS/distutils"
      PYTHONPATH="$PYTHONPATH:$DISTUTILS"
      SESSION_TYPE=filesystem FLASK_APP=./powerdnsadmin/__init__.py flask assets build
    '';
    installPhase = ''
      # https://github.com/PowerDNS-Admin/PowerDNS-Admin/blob/54b257768f600c5548a1c7e50eac49c40df49f92/docker/Dockerfile#L43
      mkdir $out
      cp -r powerdnsadmin/static/{generated,assets,img} $out
      find powerdnsadmin/static/node_modules -name webfonts -exec cp -r {} $out \; -printf "Copying %P\n"
      find powerdnsadmin/static/node_modules -name fonts -exec cp -r {} $out \; -printf "Copying %P\n"
      find powerdnsadmin/static/node_modules/icheck/skins/square -name '*.png' -exec cp {} $out/generated \;
    '';
  };

  assetsPy = writeText "assets.py" ''
    from flask_assets import Environment
    assets = Environment()
    assets.register('js_login', 'generated/login.js')
    assets.register('js_validation', 'generated/validation.js')
    assets.register('css_login', 'generated/login.css')
    assets.register('js_main', 'generated/main.js')
    assets.register('css_main', 'generated/main.css')
  '';
in
stdenv.mkDerivation {
  inherit pname version src;

  nativeBuildInputs = [ python.pkgs.wrapPython ];

  pythonPath = pythonDeps;

  gunicornScript = ''
    #!/bin/sh
    if [ ! -z $CONFIG ]; then
      exec python -m gunicorn.app.wsgiapp "powerdnsadmin:create_app(config='$CONFIG')" "$@"
    fi

    exec python -m gunicorn.app.wsgiapp "powerdnsadmin:create_app()" "$@"
  '';

  patches = all_patches ++ [
    ./0003-Fix-flask-migrate-4.0-compatibility.patch
    ./0004-Fix-flask-session-and-powerdns-admin-compatibility.patch
    ./0005-Use-app-context-to-create-routes.patch
    ./0006-Register-modules-before-starting.patch
  ];

  postPatch = ''
    rm -r powerdnsadmin/static powerdnsadmin/assets.py
    substituteInPlace powerdnsadmin/__init__.py \
      --replace-fail 'models.init_app(app)' ""
    substituteInPlace powerdnsadmin/__init__.py \
      --replace-fail 'models.base.db' 'models.base.db; models.init_app(app)'
  '';

  installPhase = ''
    runHook preInstall

    # Nasty hack: call wrapPythonPrograms to set program_PYTHONPATH (see tribler)
    wrapPythonPrograms

    mkdir -p $out/share $out/bin
    cp -r migrations powerdnsadmin $out/share/

    ln -s ${assets} $out/share/powerdnsadmin/static
    ln -s ${assetsPy} $out/share/powerdnsadmin/assets.py

    echo "$gunicornScript" > $out/bin/powerdns-admin
    chmod +x $out/bin/powerdns-admin
    # Fix so distutils is available in build prosess.
    # Function setuptools/_distutils/util.py:byte_compile is used in build prosess
    # but setuptools distutils import trick/hack is not working in build prosses
    # and we get ModuleNotfoundError 'No module named 'distutils'
    # For more explanation see first attempt:
    # https://github.com/NixOS/nixpkgs/pull/328182
    mkdir -p $out/distutils
    ln -s ${python.pkgs.setuptools}/${python.sitePackages}/setuptools/_distutils "$out/distutils/distutils"
    wrapProgram $out/bin/powerdns-admin \
      --set PATH ${python.pkgs.python}/bin \
      --set PYTHONPATH $out/share:$program_PYTHONPATH:$out/distutils

    runHook postInstall
  '';

  passthru = {
    # PYTHONPATH of all dependencies used by the package
    pythonPath = (python3.pkgs.makePythonPath pythonDeps) + ":${powerdns-admin}/distutils";
    tests = nixosTests.powerdns-admin;
  };

  meta = with lib; {
    description = "PowerDNS web interface with advanced features";
    mainProgram = "powerdns-admin";
    homepage = "https://github.com/PowerDNS-Admin/PowerDNS-Admin";
    license = licenses.mit;
    maintainers = with maintainers; [
      Flakebi
      zhaofengli
    ];
  };
}
