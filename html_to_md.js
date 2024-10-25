import fs from 'fs'

import TurndownService from 'turndown'

function main() {
  const turndownService = new TurndownService({
    headingStyle: 'atx',
    bulletListMarker: '-',
    emDelimiter: '*',
  }).addRule('image', {
    filter: 'img',
    replacement: (_content, _node) => '',
  })

  const input = fs.readFileSync(0).toString()
  const markdown = turndownService.turndown(input)
  console.log(markdown)
}

main()
