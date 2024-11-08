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

const REPLY_PREFIX = '<div class="moz-cite-prefix">'
const FORWARDED_PREFIX = '<div class="moz-forward-container">'

const MD_REPLY_PREFIX = "<!-- Original message -->"
const MD_FORWARDED_PREFIX = "<!-- Forwarded message -->"

def find_split [body: string, needle: string, suffix: string] -> Record {
  let i = $body | str index-of $needle
  if $i == -1 {
    return { body: $body, rest: null }
  }
  let forwarded = $body | str substring $i..<(($body | str length) - ($suffix | str length))
  let body = ($body | str substring ..<$i) + $suffix
  { body: $body, rest: $forwarded }
}

def split_reply [body: string] -> Record {
  find_split $body $REPLY_PREFIX $HTML_SUFFIX
}

def split_forwarded [body: string] -> Record {
  find_split $body $FORWARDED_PREFIX $HTML_SUFFIX
}

def remove_md [body: string, prefix: string] -> str {
  let index = $body | str index-of $prefix
  if $index == 0 {
    return ''
  }
  $body | str substring ..<$index
}

def join_eml [headers: string, body: string] -> str {
  let html = $HTML_PREFIX + $body + $HTML_SUFFIX
  $headers + "\n\n" + $html
}

def html_to_md [] -> str {
  $in | node $'($env.FILE_PWD)/html_to_md.js'
}

def md_to_html [] -> str {
  $in | $'($env.FILE_PWD)/.bin/marked'
}

def main [path: string] {
  # Don't use `null` to satisfy LSP

  let eml = split_eml $path

  let eml_split_forward = split_forwarded $eml.body
  let eml_split_reply = split_reply $eml.body

  mut body_md = ''

  mut forwarded_md = ''
  mut reply_html = ''
  if $eml_split_forward.rest != null {
    $body_md = $eml_split_forward.body | html_to_md
    $forwarded_md = $eml_split_forward.rest | html_to_md
    # Tidy up
    $forwarded_md = $forwarded_md
      | str replace "  \n  \n\\-------- Forwarded Message --------" ''
  } else if $eml_split_reply.rest != null {
    $body_md = $eml_split_reply.body | html_to_md
    $reply_html = $eml_split_reply.rest
  }

  mut contents_md = $"($eml.headers)\n\n($body_md)"
  if $reply_html != '' {
    let reply_md = $reply_html | html_to_md
    $contents_md = $"($contents_md)\n\n($MD_REPLY_PREFIX)\n\n($reply_md)"
  } else if $forwarded_md != '' {
    $contents_md = $"($contents_md)\n\n($MD_FORWARDED_PREFIX)\n\n($forwarded_md)"
  }
  $contents_md | save --force $path

  wezterm cli spawn --new-window -- /usr/bin/nvim $path
  let pid = pgrep --newest --full '^/usr/bin/nvim /tmp/.+\.eml$'
  tail --pid $pid --follow /dev/null

  mut eml = split_eml $path
  if $reply_html != '' {
    $eml.body = remove_md $eml.body $MD_REPLY_PREFIX
  } else if $forwarded_md != '' {
    $eml.body = remove_md $eml.body $MD_FORWARDED_PREFIX
  }

  mut html = $eml.body
    | str substring ..<($eml.body | str length)
    | markdown_py --output_format=html
  if $reply_html != '' {
    $html = $html + $eml_split_reply.rest
  } else if $forwarded_md != '' {
    $html = $html + $eml_split_forward.rest
  }
  join_eml $eml.headers $html | save --force $path
}
