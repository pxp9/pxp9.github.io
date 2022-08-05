with import <nixpkgs> {};
stdenv.mkDerivation {
  name = "env";
  buildInputs = [
    ruby
    rubyPackages.jekyll-feed
    jekyll
    libpcap
    libxml2
    libxslt
    pkg-config
    bundix
    gnumake
  ];
}
