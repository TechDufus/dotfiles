return {
  "nvim-treesitter/nvim-treesitter",
  branch = "main",
  build = ":TSUpdate",
  lazy = false,
  keys = {
    { "n", "<leader>it", ":InspectTree<CR>" },
  },
  dependencies = {
    { "nvim-treesitter/nvim-treesitter-textobjects", branch = "main" },
  },
  config = function()
    local ts = require("nvim-treesitter")
    local install_dir = vim.fs.joinpath(vim.fn.stdpath("data"), "site")
    local install_timeout_ms = 300000
    local minimum_cli_version = { 0, 26, 1 }
    local failed_installs = {}
    local warned_about_missing_cli = false
    local warned_about_incompatible_cli = false
    local managed_languages = {
      "bash",
      "css",
      "diff",
      "dockerfile",
      "git_config",
      "gitcommit",
      "go",
      "html",
      "javascript",
      "json",
      "just",
      "lua",
      "luadoc",
      "markdown",
      "markdown_inline",
      "python",
      "query",
      "regex",
      "ruby",
      "ssh_config",
      "terraform",
      "toml",
      "tsx",
      "typescript",
      "vim",
      "vimdoc",
      "yaml",
    }

    local lazy_plugin = require("lazy.core.config").plugins["nvim-treesitter"]
    if lazy_plugin then
      local runtime_dir = vim.fs.joinpath(lazy_plugin.dir, "runtime")
      if not vim.list_contains(vim.opt.runtimepath:get(), runtime_dir) then
        vim.opt.runtimepath:append(runtime_dir)
      end
    end

    local function prefer_non_plugin_parser(lang)
      local pattern = ("parser/%s.*"):format(lang)
      for _, path in ipairs(vim.api.nvim_get_runtime_file(pattern, true)) do
        if not path:find("/lazy/nvim%-treesitter/parser/") then
          vim.treesitter.language.add(lang, { path = path })
          return
        end
      end
    end

    local function has_runtime_support(lang)
      if not lang then
        return false
      end

      local has_parser = #vim.api.nvim_get_runtime_file(("parser/%s.*"):format(lang), true) > 0
      local has_queries = #vim.api.nvim_get_runtime_file(("queries/%s/highlights.scm"):format(lang), true) > 0
      return has_parser and has_queries
    end

    local function is_managed_language(lang)
      return vim.list_contains(managed_languages, lang)
    end

    local function mark_install_failed(languages)
      for _, lang in ipairs(languages) do
        failed_installs[lang] = true
      end
    end

    local function parse_semver(output)
      local major, minor, patch = output:match("(%d+)%.(%d+)%.(%d+)")
      if not major then
        return nil
      end

      return { tonumber(major), tonumber(minor), tonumber(patch) }
    end

    local function format_semver(version)
      return table.concat(version, ".")
    end

    local function semver_at_least(version, minimum)
      for index = 1, math.max(#version, #minimum) do
        local lhs = version[index] or 0
        local rhs = minimum[index] or 0
        if lhs ~= rhs then
          return lhs > rhs
        end
      end

      return true
    end

    local function get_cli_version()
      if vim.fn.executable("tree-sitter") ~= 1 then
        return nil
      end

      local result = vim.system({ "tree-sitter", "--version" }, { text = true }):wait()
      if result.code ~= 0 then
        return nil
      end

      return parse_semver(result.stdout or "")
    end

    local function get_missing_managed_languages()
      local installed_parsers = ts.get_installed("parsers")
      local installed_queries = ts.get_installed("queries")
      local missing = {}

      for _, lang in ipairs(managed_languages) do
        if
          not vim.list_contains(installed_parsers, lang)
          or not vim.list_contains(installed_queries, lang)
        then
          table.insert(missing, lang)
        end
      end

      return vim.tbl_filter(function(lang)
        return not failed_installs[lang]
      end, missing)
    end

    local function install_languages(languages)
      languages = vim.tbl_filter(function(lang)
        return not failed_installs[lang]
      end, languages)

      if #languages == 0 then
        return false
      end

      local cli_version = get_cli_version()
      if not cli_version then
        if not warned_about_missing_cli then
          warned_about_missing_cli = true
          vim.notify_once(
            "tree-sitter CLI is not installed, so managed Tree-sitter parsers cannot be bootstrapped automatically. Run the Neovim role again or install tree-sitter manually.",
            vim.log.levels.WARN
          )
        end
        mark_install_failed(languages)
        return false
      end

      if not semver_at_least(cli_version, minimum_cli_version) then
        if not warned_about_incompatible_cli then
          warned_about_incompatible_cli = true
          vim.notify_once(
            ("tree-sitter CLI %s is installed, but nvim-treesitter main requires %s or newer. Parser auto-install is disabled until the CLI is upgraded."):format(
              format_semver(cli_version),
              format_semver(minimum_cli_version)
            ),
            vim.log.levels.WARN
          )
        end
        mark_install_failed(languages)
        return false
      end

      local ok, task = pcall(ts.install, languages, { summary = true })
      if not ok then
        mark_install_failed(languages)
        vim.notify_once(
          ("Tree-sitter install failed to start for %s: %s"):format(table.concat(languages, ", "), task),
          vim.log.levels.WARN
        )
        return false
      end

      local ok_wait, installed = pcall(function()
        return task:wait(install_timeout_ms)
      end)
      if not ok_wait or not installed then
        mark_install_failed(languages)
        local reason = ok_wait and "installer returned unsuccessful status" or installed
        vim.notify_once(
          ("Tree-sitter install failed for %s: %s"):format(table.concat(languages, ", "), tostring(reason)),
          vim.log.levels.WARN
        )
        return false
      end

      return true
    end

    -- Old nvim-treesitter installs can leave stale parser binaries in the plugin checkout.
    -- Prefer Neovim's own `vim` parser so command-line buffers don't load an incompatible binary.
    ts.setup({
      install_dir = install_dir,
    })

    prefer_non_plugin_parser("vim")
    install_languages(get_missing_managed_languages())

    local group = vim.api.nvim_create_augroup("techdufus_treesitter", { clear = true })

    vim.api.nvim_create_autocmd("FileType", {
      group = group,
      pattern = "*",
      callback = function(args)
        if vim.bo[args.buf].buftype ~= "" then
          return
        end

        local lang = vim.treesitter.language.get_lang(vim.bo[args.buf].filetype)
        if not lang then
          return
        end

        if not has_runtime_support(lang) and is_managed_language(lang) then
          install_languages({ lang })
        end

        if not has_runtime_support(lang) then
          return
        end

        if not pcall(vim.treesitter.start, args.buf, lang) then
          return
        end

        if #vim.api.nvim_get_runtime_file(("queries/%s/indents.scm"):format(lang), true) > 0 then
          vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        end
      end,
    })
  end
}
