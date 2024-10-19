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

const MD_START = '<pre><code class="language-md">'
const MD_END = '</code></pre>'

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

def add_md [s: string, md: string] -> str {
  $"($s)\n\n($MD_START)\n($md)\n($MD_END)"
}

def remove_reply_md [body: string] -> str {
  let reply_index = $body | str index-of $"\n\n($MD_START)\nOn "
  $body | str substring ..<$reply_index
}

def remove_forwarded_md [body: string] -> str {
  let forwarded_index = $body | str index-of $"\n\n($MD_START)\n-------- Forwarded Message --------"
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
  # Don't use `null` to satisfy LSP

  let eml = split_eml $path

  let eml_split_forward = split_forwarded $eml.body
  let eml_split_reply = split_reply $eml.body

  mut body_md = ''

  mut forwarded_md = ''
  mut reply_html = ''
  if $eml_split_forward.rest != null {
    $body_md = $eml_split_forward.body | to_markdown
    $forwarded_md = $eml_split_forward.rest | to_markdown
    # Tidy up
    $forwarded_md = $forwarded_md
      | str replace '\-\-\-\-\-\-\-\- Forwarded Message \-\-\-\-\-\-\-\-' '-------- Forwarded Message --------'
  } else if $eml_split_reply.rest != null {
    $body_md = $eml_split_reply.body | to_markdown
    $reply_html = $eml_split_reply.rest
  }

  mut contents_md = add_md $eml.headers $body_md
  if $reply_html != '' {
    let reply_md = $reply_html | to_markdown
    $contents_md = add_md $contents_md $reply_md
  } else if $forwarded_md != '' {
    $contents_md = add_md $contents_md $forwarded_md
  }
  $contents_md | save --force $path

  wezterm cli spawn --new-window -- /usr/bin/nvim $path
  let pid = pgrep --newest --full '^/usr/bin/nvim /tmp/.+\.eml$'
  tail --pid $pid --follow /dev/null

  mut eml = split_eml $path
  if $reply_html != '' {
    $eml.body = remove_reply_md $eml.body
  } else if $forwarded_md != '' {
    $eml.body = remove_forwarded_md $eml.body
  }

  mut html = $eml.body
    | str substring ($MD_START | str length)..<(($eml.body | str length) - ($MD_END | str length))
    | markdown_py --output_format=html
  if $reply_html != '' {
    $html = $html + $eml_split_reply.rest
  } else if $forwarded_md != '' {
    $html = $html + $eml_split_forward.rest
  }
  join_eml $eml.headers $html | save --force $path
}
