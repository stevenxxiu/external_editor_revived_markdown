#!/usr/bin/nu
def split_eml [path: string] -> Record {
  let contents = open --raw $path | str replace --all "\r\n" "\n"
  let headers_len = $contents | str index-of "\n\n"
  let body_offset = $headers_len + 2
  let headers = $contents | str substring ..<$headers_len
  let body = $contents | str substring $body_offset..
  { headers: $headers, body: $body }
}

# From editing a blank *Thunderbird* email
const HTML_PREFIX = [
  '<!DOCTYPE html>'
  '<html><head>'
  '<meta http-equiv="content-type" content="text/html; charset=UTF-8"></head><body>'
] | str join "\n"
const HTML_SUFFIX = '</body></html>'

const FORWARDED_PREFIX = '<div class="moz-forward-container">'
const FORWARDED_SUFFIX = '</div>'

def remove_forwarded [body: string] -> Record {
  let i = $body | str index-of $FORWARDED_PREFIX
  if $i == -1 {
    return { forwarded: null, body: $body }
  }
  let forwarded = $body | str substring $i..<(($body | str length) - ($HTML_SUFFIX | str length))
  let body = ($body | str substring ..<$i) + $HTML_SUFFIX
  { forwarded: $forwarded, body: $body }
}

def remove_forwarded_md [body: string, forwarded: string] -> str {
  $body | str substring ..<(($body | str length) - ($forwarded | str length) - 2)
}

def add_forwarded_md [body: string, forwarded: string] -> str {
  $"($body)\n\n($forwarded)"
}

def join_eml [headers: string, body: string] -> str {
  let html = $HTML_PREFIX + $body + $HTML_SUFFIX
  $headers + "\n\n" + $html
}

def main [path: string] {
  let eml = split_eml $path
  let obj = remove_forwarded $eml.body
  let forwarded = $obj.forwarded
  let body = $obj.body
  mut markdown = (
    $body
    | markdownify --bullets '-'
    | str trim
  )
  mut contents_md = $eml.headers + "\n\n" + $"<pre>\n($markdown)\n</pre>"
  if $forwarded != null {
    $contents_md = add_forwarded_md $contents_md $forwarded
  }
  $contents_md | save --force $path

  wezterm cli spawn --new-window -- /usr/bin/nvim $path
  let pid = pgrep --newest --full '^/usr/bin/nvim /tmp/.+\.eml$'
  tail --pid $pid --follow /dev/null

  mut eml = split_eml $path
  if $forwarded != null {
    $eml.body = remove_forwarded_md $eml.body $forwarded
  }

  mut html = $eml.body
    | str substring 6..<-6  # Strip `<pre></pre>`
    | markdown_py --output_format=html
  if $forwarded != null {
    $html = $html + $forwarded
  }
  join_eml $eml.headers $html | save --force $path
}
