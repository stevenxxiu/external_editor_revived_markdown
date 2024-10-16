#!/usr/bin/nu
def split_eml [path: string] {
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

def join_eml [headers: string, body: string] {
  let html = $HTML_PREFIX + $body + $HTML_SUFFIX
  $headers + "\n\n" + $html
}

def main [path: string] {
  let eml = split_eml $path
  mut markdown = (
    $eml.body
    | markdownify --bullets '-'
    | str trim
  )
  let contents_md = $eml.headers + "\n\n" + $"<pre>\n($markdown)\n</pre>"
  $contents_md | save --force $path

  wezterm cli spawn --new-window -- /usr/bin/nvim $path
  let pid = (pgrep --newest --full '^/usr/bin/nvim /tmp/.+\.eml$')
  tail --pid $pid --follow /dev/null

  let eml = split_eml $path
  join_eml $eml.headers (
    $eml.body
    | str substring 6..<-6  # Strip `<pre></pre>`
    | markdown_py --output_format=html
  )
  | save --force $path
}
