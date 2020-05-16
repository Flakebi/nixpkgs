{ stdenv
, fetchFromGitHub
, nodejs
, python2
, mkYarnPackage
}:

mkYarnPackage rec {
  name = "ackee";
  version = "1.7.1";

  pkgConfig.gyp.buildInputs = [ python2 ];

  src = fetchFromGitHub {
    owner = "electerious";
    repo = "Ackee";
    rev = "v${version}";
    sha256 = "1b4iw9i59qnkmjhb381k0a6gbk1vnhyx4vskss7gshzpi4jak1j8";
  };

  yarnFlags = [
    "--offline"
    "--frozen-lockfile"
  ];
  yarnPreBuild = ''
    yarn config --offline set nodedir ${nodejs}
  '';

  postConfigure = ''
    rm -r node_modules/node-sass/build
  '';

  distPhase = ''
    runHook preDist

    rm $out/libexec/ackee/deps/ackee/node_modules
    ln -sf $out/libexec/ackee/node_modules $out/libexec/ackee/deps/ackee/node_modules

    cat > $out/bin/ackee <<EOF
    #!${stdenv.shell}
    cd $out/libexec/ackee/deps/ackee
    export NODE_PATH="$out/libexec/ackee/node_modules"
    exec ${nodejs}/bin/node $out/libexec/ackee/deps/ackee/src/index.js
    EOF

    chmod +x $out/bin/ackee

    runHook postDist
  '';

  meta = with stdenv.lib; {
    description = "Self-hosted, Node.js based analytics tool for those who care about privacy";
    license = licenses.mit;
    homepage = "https://ackee.electerious.com";
    maintainers = with maintainers; [ Flakebi ];
    platforms = platforms.linux;
  };
}
