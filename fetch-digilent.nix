# files.digilent.com answers 403 to curl's default user agent (and to a bare
# "Mozilla/5.0"), so send a full browser one.
{ fetchurl }:

{
  name,
  url,
  hash,
}:

fetchurl {
  inherit name url hash;
  curlOptsList = [
    "--user-agent"
    "Mozilla/5.0 (X11; Linux x86_64; rv:158.0) Gecko/20100101 Firefox/158.0"
  ];
}
