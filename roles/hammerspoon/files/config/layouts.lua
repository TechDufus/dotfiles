return {
  {
    name = 'Standard Dev',
    cells = {
      { '0,0 7x20', '0,0 7x20' },
      { '7,0 21x20', '7,0 30x20' },
      { '28,0 32x20', '37,0 23x20' },
      { '42,2 16x16', '42,2 16x16' },
      { '30,3 20x14', '39,3 16x14' },
    },
    apps = {
      Ray = { cell = 1, open = true },
      Brave = { cell = 2, open = true },
      Obsidian = { cell = 2 },
      WezTerm = { cell = 3, open = true },
      Tower = { cell = 3 },
      Slack = { cell = 4 },
      Discord = { cell = 5 },
    },
  },
  {
    name = 'No Ray',
    cells = {
      { '0,0 21x20' },
      { '21,0 39x20' },
    },
    apps = {
      Brave = { cell = 1, open = true },
      WezTerm = { cell = 2, open = true },
      Tower = { cell = 2 },
    },
  },
  {
    name = 'Code Focused',
    cells = {
      { '0,0 7x20', positions.sixths.left },
      { '7,0 53x20', positions.fiveSixths.right },
    },
    apps = {
      Ray = { cell = 1, open = true },
      WezTerm = { cell = 2, open = true },
      Brave = { cell = 2, open = true },
      Tower = { cell = 2 },
    },
  },
}
