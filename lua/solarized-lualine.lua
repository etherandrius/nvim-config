local light_colors = {
    base3  =  8,
    base2  =  0,
    base1  =  10,
    base0  =  11,
    base00   =  12,
    base01   =  14,
    base02   =  7,
    base03   =  15,
    yellow  =  3,
    orange  =  9,
    red     =  1,
    magenta =  5,
    violet  =  13,
    blue    =  4,
    cyan    =  6,
    green   =  2,
}


local dark_colors = {
    base03  =  8,
    base02  =  0,
    base01  =  10,
    base00  =  11,
    base0   =  12,
    base1   =  14,
    base2   =  7,
    base3   =  15,
    yellow  =  3,
    orange  =  9,
    red     =  1,
    magenta =  5,
    violet  =  13,
    blue    =  4,
    cyan    =  6,
    green   =  2,
  }

local colors = function (colors)
  return {
    normal = {
      a = { fg = colors.base03, bg = colors.blue, gui = 'bold' },
      b = { fg = colors.base3, bg = colors.base03 },
      c = { fg = colors.base03, bg = colors.blue },
    },
    insert = {
      a = { fg = colors.base03, bg = colors.green, gui = 'bold' },
      b = { fg = colors.base3, bg = colors.base03 },
      c = { fg = colors.base03, bg = colors.green },
    },
    visual = {
      a = { fg = colors.base03, bg = colors.magenta, gui = 'bold' },
      b = { fg = colors.base3, bg = colors.base03 },
      c = { fg = colors.base03, bg = colors.magenta },
    },
    replace = {
      a = { fg = colors.base03, bg = colors.red, gui = 'bold' },
      b = { fg = colors.base3, bg = colors.base03 },
      c = { fg = colors.base03, bg = colors.red },
    },
    inactive = {
      a = { fg = colors.base0, bg = colors.base02, gui = 'bold' },
      b = { fg = colors.base03, bg = colors.base00 },
      c = { fg = colors.base02, bg = colors.base01 },
    },
  }
end

local background = vim.opt.background:get()
if background == 'light' then
  return colors(light_colors)
end
return colors(dark_colors)

