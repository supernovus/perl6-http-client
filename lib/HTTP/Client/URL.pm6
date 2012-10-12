## The old standalone, very minimalistic grammar we used when URI was broken.
## This will likely be removed in an upcoming version, and isn't being used.
grammar HTTP::Client::URL {
  regex TOP {
    ^
      <proto>
      '://'
      [<auth>'@']?
      <host>
      [':'<port>]?
      <path>
    $
  }
  token proto { \w+ }
  token host  { [\w|'.'|'-']+ }
  token port  { \d+ }
  token user  { \w+ }               ## That's right, simplest usernames only.
  token pass  { [\w|'-'|'+'|'%']+ } ## Fairly simple passwords only too.
  token auth  { <user> ':' <pass> } ## This assumes Basic Auth.
  regex path  { .* }
}

