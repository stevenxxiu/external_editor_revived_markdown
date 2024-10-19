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

def split_forwarded [body: string] -> Record {
  let i = $body | str index-of $FORWARDED_PREFIX
  if $i == -1 {
    return { forwarded: null, body: $body }
  }
  let forwarded = $body | str substring $i..<(($body | str length) - ($HTML_SUFFIX | str length))
  let body = ($body | str substring ..<$i) + $HTML_SUFFIX
  { forwarded: $forwarded, body: $body }
}

def add_md [s: string, md: string] -> str {
  $"($s)\n\n<pre>\n($md)\n</pre>"
}

def remove_forwarded_md [body: string] -> str {
  let forwarded_index = $body | str index-of "\n\n<pre>\n-------- Forwarded Message --------"
  $body | str substring ..<$forwarded_index
}

def join_eml [headers: string, body: string] -> str {
  let html = $HTML_PREFIX + $body + $HTML_SUFFIX
  $headers + "\n\n" + $html
}

def to_markdown [] -> str {
  (
    $in
    | markdownify
      --heading-style 'atx'
      --bullets '-'
      --keep-inline-images-in
    | str trim
  )
}

def main [path: string] {
  let eml = split_eml $path
  let eml_split = split_forwarded $eml.body

  mut body_md = $eml_split.body | to_markdown
  mut forwarded_md = ''  # Don't use `null` to satisfy LSP
  if $eml_split.forwarded != null {
    $forwarded_md = $eml_split.forwarded | to_markdown
    # Tidy up
    $forwarded_md = $forwarded_md
      | str replace '\-\-\-\-\-\-\-\- Forwarded Message \-\-\-\-\-\-\-\-' '-------- Forwarded Message --------'
  }
  mut contents_md = add_md $eml.headers $body_md

  if $forwarded_md != '' {
    $contents_md = add_md $contents_md $forwarded_md
  }
  $contents_md | save --force $path

  wezterm cli spawn --new-window -- /usr/bin/nvim $path
  let pid = pgrep --newest --full '^/usr/bin/nvim /tmp/.+\.eml$'
  tail --pid $pid --follow /dev/null

  mut eml = split_eml $path
  if $forwarded_md != '' {
    $eml.body = remove_forwarded_md $eml.body
  }

  mut html = $eml.body
    | str substring 6..<-6  # Strip `<pre></pre>`
    | markdown_py --output_format=html
  if $forwarded_md != '' {
    $html = $html + $eml_split.forwarded
  }
  join_eml $eml.headers $html | save --force $path
}
