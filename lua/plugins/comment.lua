-- Comment.nvim shortcuts:
-- Normal mode: gcc (toggle line), gc{motion}, gbc (toggle block), gb{motion}
-- Visual mode: gc (line comment), gb (block comment)
-- Examples: gc2j, gcip, gca}, gb2j
return {
  "numToStr/Comment.nvim",
  config = function()
    require('Comment').setup()
  end
}

