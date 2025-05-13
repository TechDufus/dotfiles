local opt = vim.opt

opt.tabstop = 4
opt.colorcolumn = "80"

function custom_java_switch_command(name)
  if string.match(name, "Tests%.java$") then
    -- Change from src/test/package/FileTests.java to src/main/package/File.java
    return string.gsub(name, "(src/test)/(.*)Tests%.java", "src/main/%2.java")
  elseif string.match(name, "%.java$") then
    -- Change from src/main/package/File.java to src/test/package/FileTests.java
    return string.gsub(name, "(src/main)/(.*)%.java", "src/test/%2Tests.java")
  else
    -- Do nothing
    return name
  end
end
vim.cmd([[
command! -nargs=0 JavaSwitch lua vim.cmd("e " .. vim.fn.luaeval('custom_java_switch_command(vim.fn.expand("%"))')) ]])
