{ pkgs ? import <nixpkgs> {} }: let

stream = pkgs.writers.writeDashBin "stream" ''
  RESOLUTION=$(${pkgs.xorg.xrandr}/bin/xrandr | ${pkgs.gnugrep}/bin/grep \* | ${pkgs.gawk}/bin/awk '{print $1}')
  FILENAME=''${1:-stream_dump.flv}
  URL=''${URL:-'rtmp://localhost:1935/stream/test'}
  ${pkgs.ffmpeg}/bin/ffmpeg \
    -f x11grab \
    -s "$RESOLUTION" \
    -framerate 25 \
    -i :0.0 \
    -f pulse \
    -i default \
    -f flv \
    -qmax 10 \
    "$URL" \
    "$FILENAME"
'';

nginxCfg = pkgs.writeText "nginx.conf" ''
  worker_processes  1;
  daemon off;

  error_log stderr;
  pid nginx.pid;

  events {
      worker_connections  1024;
  }

  rtmp {
      server {
          access_log stderr;
          listen 1935;
          ping 30s;
          notify_method get;

          application stream {
              live on;
          }
      }
  }
'';

runNginx = pkgs.writers.writeDashBin "run_nginx" ''
  mkdir -p /tmp/rtmp
  ${pkgs.nginx.override {
    modules = [
      pkgs.nginxModules.rtmp
    ];
  }}/bin/nginx -c ${nginxCfg} -p /tmp/rtmp
'';

in pkgs.stdenv.mkDerivation {
  name = "stream-shell";
  buildInputs = [
    stream
    runNginx
  ];
}
